# DeepSeek-V4 Paper Extracts

## Table 4 | Tool-call schema for DeepSeek-V4 series.

**Tool Call Schema**

```text
## Tools

You have access to a set of tools to help answer the user's question. You can
invoke tools by writing a "<|DSML|tool_calls>" block like the following:

<|DSML|tool_calls>
<|DSML|invoke name="$TOOL_NAME">
<|DSML|parameter name="$PARAMETER_NAME" string="true|false">$PARAMETER_VALUE
</|DSML|parameter>
...
</|DSML|invoke>
<|DSML|invoke name="$TOOL_NAME2">
...
</|DSML|invoke>
</|DSML|tool_calls>

String parameters should be specified as is and set `string="true"`. For all
other types (numbers, booleans, arrays, objects), pass the value in JSON
format and set `string="false"`.

If thinking_mode is enabled (triggered by <think>), you MUST output your
complete reasoning inside <think>...</think> BEFORE any tool calls or
final response.

Otherwise, output directly after </think> with tool calls or final response.

### Available Tool Schemas

{Tool Definition...}

You MUST strictly follow the above definedtool name and parameter schemas to
invoke tool calls.
```

---

## Thinking Management (Interleaved Thinking in Agentic Environments)

...window of DeepSeek-V4 series, we further refine this mechanism to maximize the effectiveness of interleaved thinking in agentic environments:

*   **Tool-Calling Scenarios.** As illustrated in Figure 7(a), all reasoning content is fully pre-served throughout the entire conversation. Unlike DeepSeek-V3.2, which discarded thinking traces upon each new user turn, DeepSeek-V4 series retain the complete reasoning history across all rounds, including across user message boundaries. This allows the model to maintain a coherent, cumulative chain of thought over long-horizon agent tasks.
*   **General Conversational Scenarios.** As illustrated in Figure 7(b), the original strategy is preserved: reasoning content from previous turns is discarded when a new user message arrives, keeping the context concise for settings where persistent reasoning traces provide limited benefit.

As with DeepSeek-V3.2, agent frameworks that simulate tool interactions via user messages (e.g., Terminus) may not trigger the tool-calling context path and thus may not benefit from enhanced reasoning persistence. We continue to recommend non-think models for such architectures.

---

## Quick Instruction

**Quick Instruction.** In chatbot scenarios, a number of auxiliary tasks (e.g., determining whether to trigger a web search, intent recognition, etc.) must be executed before generating the response. Conventionally, these tasks are handled by a separate small model, requiring redundant prefilling since it cannot reuse the existing KV cache. To overcome this limitation, we introduce Quick Instruction. We append a set of dedicated special tokens directly to the input sequence, where each token corresponds to a specific auxiliary task. By directly reusing the already-computed KV cache, this mechanism completely avoids redundant prefilling and allows certain tasks, such as generating search queries and determining authority and domain, to be executed in parallel. Consequently, this approach significantly reduces the user-perceived time-to-first-token (TTFT) and eliminates the engineering overhead of maintaining and iterating an extra small model. The supported Quick Instruction tokens are summarized in Table 5.

### Table 5 | Quick Instruction special tokens for auxiliary tasks.

| Special Token | Description | Format |
| :--- | :--- | :--- |
| `<|action|>` | Determines whether the user prompt requires a web search or can be answered directly. | `...<|User|>{prompt}<|Assistant|><think><|action|>` |
| `<|title|>` | Generates a concise conversation title after the first assistant response. | `...<|Assistant|>{response}<|end_of_sentence|><|title|>` |
| `<|query|>` | Generates search queries for the user prompt. | `...<|User|>{prompt}<|query|>` |
| `<|authority|>` | Classifies the user prompt's demand for source authoritativeness. | `...<|User|>{prompt}<|authority|>` |
| `<|domain|>` | Identifies the domain of the user prompt. | `...<|User|>{prompt}<|domain|>` |
| `<|extracted_url|>`<br>`<|read_url|>` | Determines whether each URL in the user prompt should be fetched and read. | `...<|User|>{prompt}<|extracted_url|>{url}<|read_url|>` |

---

## 5.2 RL and OPD Infrastructures (Summary)

Our post-training infrastructure is built upon the scalable framework developed for DeepSeek-V3.2. Specifically, we integrate the same distributed training stack described in Section 3.5 and the rollout engine introduced earlier...

*   **5.2.1. FP4 Quantization Integration**: Accelerates both rollouts and all inference-only forward passes, reducing memory traffic and sampling latency... simulated via a lossless FP4-to-FP8 dequantization step...
*   **5.2.2. Efficient Teacher Scheduling for Full-Vocabulary OPD**: Supports full-vocabulary On-Policy Distillation (OPD) with an effectively unbounded number of teachers... caches only the last-layer teacher hidden states in a centralized buffer during the forward pass...
*   **5.2.3. Preemptible and Fault-Tolerant Rollout Service**: Cluster-wide preemptive task scheduler and a token-granular Write-Ahead Log (WAL) for each generation request to handle preemption and hardware failures.
