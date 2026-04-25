# Web 逆向代理接入 Tool Call 鲁棒性优化技术指南

本文档旨在为开发大模型（LLM）Web 端逆向代理（如将网页版 ChatGPT、Claude、DeepSeek 转换为 OpenAI 标准 API 接口）的开发者，提供一套**极其鲁棒的 Tool Call（工具调用）实现方案**。

## 1. 前置知识：什么是 Tool Call（工具调用）？

**Tool Call**（工具调用，或称 Function Calling）是 OpenAI 率先提出并被业界广泛遵守的一种大模型能力。它允许大语言模型在对话过程中不再只输出纯文本，而是**格式化地向客户端输出它想要调用的第三方工具名称及所需参数**。

例如，当用户问“当前时间是几点？”时，模型本身缺乏实时感知，它会输出类似下面这样标准的 **OpenAI JSON 规范数据**：
```json
{
  "tool_calls": [
    {
      "id": "call_abc123",
      "type": "function",
      "function": {
        "name": "get_time_info",
        "arguments": "{}"  // 注意：此处必须是由有效 JSON 对象序列化而成的字符串
      }
    }
  ]
}
```
你的本地客户端（如 Kilo 或 Cursor）收到上述 JSON 后，在你的电脑上执行获取时间的操作，随后把结果传回给模型，模型再基于结果回答。这就是所谓的 Tool Call，它等于**赋予了大语言模型连接物理世界的手足**。

### 1.1 客户端是如何告诉大模型有哪些工具的？
在 OpenAI 规范中，客户端在发起对话请求时，会通过在 Body 中带上一个 `tools` 数组来把工具列表“注册”给大模型。它的规范强烈依赖于 **JSON Schema** 定义。典型的 `tools` 传入结构如下：

```json
{
  "model": "gpt-4",
  "messages": [ ... ],
  "tools": [
    {
      "type": "function",
      "function": {
        "name": "get_weather",
        "description": "获取指定城市的当前天气情况",
        "parameters": {
          "type": "object",
          "properties": {
            "location": {
              "type": "string",
              "description": "城市名称，例如：北京, 上海"
            }
          },
          "required": ["location"]
        }
      }
    }
  ]
}
```
**规范解析：**
* **type**: 目前固定为 `"function"`。
* **name & description**: 工具名称和描述，大模型完全靠阅读这个 `description` 来决定什么时候该调什么工具。
* **parameters**: 这是标准的 **JSON Schema** 语法。通过 `type`, `properties` 和 `required` 约束大模型返回工具参数时的名字和类型。

我们在逆向代理后端的 `format_tools_to_system_prompt` 函数中，做的第一件事就是把这个 JSON Schema 解析出来，拍扁成了纯文本，然后贴在我们的 XML 提示词里给底层大语言模型学习。

**转换后呈现给大模型的样子（示例）：**
```markdown
### AVAILABLE TOOLS

#### Tool: `get_weather`
Description: 获取指定城市的当前天气情况
Parameters: {"type": "object", "properties": {"location": {"type": "string", "description": "城市名称，例如：北京, 上海"}}, "required": ["location"]}
```

---


## 2. 核心痛点与解决思路

### 1.1 传统 JSON 协议的痛点
OpenAI 官方的标准 Tool Call 协议要求大模型直接输出 JSON 格式。在网页逆向代理场景中，如果依靠提示词强迫模型输出 JSON，很容易遭遇灾难性解析失败（`JSONDecodeError`）：
1. **长文本转义噩梦**：当工具被用来生成长段代码（如含有大量 `\` 的 LaTeX 源码、含有 `"` 的 Python 代码）时，模型极容易忘写转义符。
2. **标签吃漏幻觉**：长文本生成导致注意力衰减，模型常常在生成大型嵌套数组（如多项选择题选项）时，丢失末尾的闭合符号。

### 1.2 核心解法：混合协议 (XML 外壳 + JSON 内核)
我们摒弃了纯 JSON 协议的死板，转而采用一种更符合大模型预训练语料分布的混合协议：
* **外壳与普通字段选用 XML**：利用 XML 不需求对内部文本特殊字符进行转义的天然优势，原封不动地包裹长代码。
* **复杂对象降级为 JSON**：对于明确的数组（Array）或对象（Object）参数，在 XML 标签内部强制输出 JSON，便于反序列化。

---

## 3. 提示词工程 (Prompt Engineering) 全流程

要让模型完全按照混合协议输出，需要在请求构建阶段进行三步拦截：

### 第一步：构建强约束系统提示词 (System Prompt)
在传递给模型的系统提示词最上方，注入高优先级的指令：

```markdown
### [CRITICAL] TOOL CALLING INSTRUCTIONS

If you want to call a tool, you MUST output an XML block wrapped in <tool_call> and </tool_call> tags.
DO NOT output any other XML tags except below or markdown tag (eg:```xml) for tool calls.

IMPORTANT: For simple string parameters, place the raw text directly inside the tag (NO escape needed). However, if a parameter expects an Array or Object, you MUST output valid JSON format inside the tag.

Format:
<tool_call>
  <tool name="tool_name">
    <arguments>
      <arg_name>value</arg_name>
    </arguments>
  </tool>
</tool_call>
```
* **技巧**：务必添加 Few-shot Example，且务必涵盖 **纯文本多行代码示例**（如写一个 Python 文件）和 **JSON 数组示例**，防止模型举棋不定。

### 第二步：上下文自动修复 (History Alignment)
如果会话中有多轮工具调用，客户端历史记录发来的可能仍是标准的 JSON `tool_calls`。**必须将其转换为上述的 XML 格式**，再提交给底层模型。保持历史记录格式与系统提示词格式的绝对一致。

### 第三步：末尾强制锚点 (Anchor Reminder)
大模型在阅读极长的上下文后会诱发“格式遗忘”。在拼接最后一条 `User` 消息后，以固定模式追加格式复习标签：

```text
[TOOLCALL_FORMAT_REMINDER]:
<tool_call>
  <tool name="tool_name">
    <arguments>
      <param_name>value</param_name>
    </arguments>
  </tool>
</tool_call>
```
这种在对话末尾的“首因-近因效应”能够极大地保证模型不偏离 XML 结构。

---

## 4. 后端解析器 (Parser) 健壮性实现

模型输出流（Stream）返回后，需要在网关层解析 XML，再将其打包为 OpenAI 兼容的 JSON 发还给客户端程序。

### 4.1 Python 解析器参考实现

```python
import re
import json

def parse_tool_call_any(text: str):
    """
    尝试解析混合格式的 tool_call。
    返回 (name, arguments_dict)
    """
    name = None
    
    # 1. 提取工具名称。兼容 <name> 或 <tool name="xxx"> 等多语言习惯
    name_match = re.search(r'<name>(.*?)</name>', text, re.DOTALL)
    if name_match:
        name = name_match.group(1).strip()
    else:
        name_match = re.search(r'<(?:tool|tool_call)\s+name=["\']([^"\']+)["\']', text)
        if name_match:
            name = name_match.group(1).strip()

    if not name:
        return None, None

    args = {}
    
    # 2. 定位 arguments 区块
    args_section = re.search(r'<arguments>(.*?)</arguments>', text, re.DOTALL)
    content_to_search = args_section.group(1) if args_section else text
    
    # 3. 提取所有参数标签。
    # 终极宽容正则：(?=</arguments>|$) 允许大模型遗漏参数闭合标签（经常发生）
    tag_pattern = re.compile(
        r'<([^>/\s]+)>(.*?)(?:</\1>|(?=</arguments>)|(?=</tool_call>)|(?=</tool>)|$)', 
        re.DOTALL
    )
    for tm in tag_pattern.finditer(content_to_search):
        tag, val = tm.group(1), tm.group(2)
        if tag not in ["name", "arguments", "tool_call", "tool"]:
            val_stripped = val.strip()
            
            # 4. JSON 回退探测：如果里面包含数组或对象，尝试反序列化
            if (val_stripped.startswith('{') and val_stripped.endswith('}')) or \
               (val_stripped.startswith('[') and val_stripped.endswith(']')):
                try:
                    args[tag] = json.loads(val_stripped)
                except json.JSONDecodeError:
                    args[tag] = val_stripped  # 解析失败亦不要抛错，作为字符串保留
            else:
                args[tag] = val.strip()  # 普通文本（如大段代码）只做去两端空格处理
                
    return name, args
```

### 4.2 流程说明
1. **贪婪降级匹配**：在解析结束标签时，使用非贪婪匹配 `(.*?)` 后接前瞻断言 `(?=</arguments>)`，完美克制大模型丢失结束标签的幻觉问题。
2. **零转义保留**：未命中 JSON 探测的参数即被当作普通字符串，这意味着 LaTeX、Python 脚本内的反斜杠和引号将原样传至下游。

---

## 5. OpenAI 格式兼容装配

最后阶段，将解析所得构造为标准的 OpenAI Delta 或 Response JSON，以便诸如 Kilo、Cursor 等客户端顺利消费：

```python
t_name, t_args_dict = parse_tool_call_any(xml_str)
if t_name:
    # OpenAI 标准协议中，复杂对象的 arguments 本身需作为通过 JSON 序列化的 String 返回
    t_args_str = json.dumps(t_args_dict, ensure_ascii=False) if isinstance(t_args_dict, dict) else str(t_args_dict)
    
    openai_tool_chunk = {
        "tool_calls": [{
            "index": 0,
            "id": f"call_{int(time.time())}",
            "type": "function",
            "function": {
                "name": t_name,
                "arguments": t_args_str
            }
        }]
    }
```
通过上述方式，哪怕代理后端是以完全非标的 XML 方式从模型榨取数据，对最终客户端而言，这依然是一个拥有完美数据结构的、标准且极其稳定的 OpenAI API Endpoint。
