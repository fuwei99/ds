# 部署到 Hugging Face Spaces 指南

本项目已经针对 Hugging Face Spaces (Docker) 进行了优化。以下是部署步骤：

## 1. 准备工作

确保你已经注册了 [Hugging Face](https://huggingface.co/) 账号，并创建了一个 **Space**。
*   **Space SDK**: 选择 **Docker**
*   **Space Hardware**: 免费的 CPU Basic 即可 (此项目对计算资源要求不高)

## 2. 推送代码到 Space

你可以通过 git 将代码推送到你的 Space 仓库。

```bash
# 1. 克隆你的 Space 仓库 (替换为你自己的 Space 地址)
git clone https://huggingface.co/spaces/YOUR_USERNAME/YOUR_SPACE_NAME

# 2. 将本项目的所有文件复制到克隆下来的目录中
# (注意：不要覆盖 .git 目录)

# 3. 提交并推送
cd YOUR_SPACE_NAME
git add .
git commit -m "Deploy deepseek2api"
git push
```

或者，你也可以直接在 Hugging Face 网页端上传文件（不推荐，文件较多）。

## 3. 配置环境变量 (关键步骤)

由于 `config.json` 包含敏感信息（Token、密码等），**绝对不要**将其直接上传到公开的仓库中。
我们使用 Hugging Face 的 **Secrets** (环境变量) 来注入配置。

1.  进入你的 Space 页面，点击 **Settings** 选项卡。
2.  找到 **Variables and secrets** 部分。
3.  点击 **New secret**。
4.  **Name** (键名): `CONFIG_JSON`
5.  **Value** (键值): 将你本地 `config.json` 的**全部内容**复制进去。

    例如：
    ```json
    {
      "keys": [
        "sk-deepseek2api"
      ],
      "auto_upload_token_threshold": 400000,
      "auto_upload_char_threshold_max": 700000,
      "auto_upload_char_threshold_min": 400000,
      "accounts": [
        {
          "email": "your_email@gmail.com",
          "password": "your_password",
          "token": "your_token_here"
        }
      ]
    }
    ```
    *(注意：确保 JSON 格式正确，不要有多余的空格或换行导致解析失败)*

## 4. 等待构建完成

推送代码并配置好 Secret 后，Hugging Face 会自动开始构建 Docker 镜像。
构建完成后，Space 状态会变为 **Running**。

## 5. 使用

Space 运行后，你会获得一个 URL（例如 `https://your-username-space-name.hf.space`）。
你可以像使用本地服务一样使用这个 URL：

*   **API 地址**: `https://your-username-space-name.hf.space/v1/chat/completions` (假设你用的是兼容 OpenAI 的客户端)
*   **API Key**: `sk-deepseek2api` (或者你在 config.json 中设置的其他 key)

---

## 常见问题

### 为什么构建失败？
*   检查 `Dockerfile` 是否在根目录。
*   查看 **Logs** 选项卡中的构建日志。

### 为什么应用启动了但无法连接？
*   确保 `Dockerfile` 中暴露了端口 7860 (`EXPOSE 7860`)。
*   本项目已自动处理端口设置，只需确保没有修改 `CMD` 覆盖默认行为。

### 如何更新配置？
*   只需修改 Space Settings 中的 `CONFIG_JSON` Secret，应用会自动重启并加载新配置。
