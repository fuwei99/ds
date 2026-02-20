#!/bin/bash
# Start DeepSeek2API in the background on port 5001
export PORT=5001
python app.py &

# Check if litellm_config.yaml exists, if not create a default one
if [ ! -f "litellm_config.yaml" ]; then
cat << 'EOF' > litellm_config.yaml
litellm_settings:
  drop_params: true

model_list:
  - model_name: deepseek-chat
    litellm_params:
      model: openai/deepseek-chat
      api_base: http://127.0.0.1:5001/v1
      api_key: wei123..
      supports_function_calling: true
  - model_name: deepseek-chat-search
    litellm_params:
      model: openai/deepseek-chat-search
      api_base: http://127.0.0.1:5001/v1
      api_key: wei123..
      supports_function_calling: true
  - model_name: deepseek-reasoner
    litellm_params:
      model: openai/deepseek-reasoner
      api_base: http://127.0.0.1:5001/v1
      api_key: wei123..
      supports_function_calling: true
  - model_name: deepseek-reasoner-search
    litellm_params:
      model: openai/deepseek-reasoner-search
      api_base: http://127.0.0.1:5001/v1
      api_key: wei123..
      supports_function_calling: true
EOF
fi

# Start LiteLLM proxy in the foreground on the exposed port (usually 7860 on huggingface)
echo "Starting LiteLLM proxy..."
litellm --config litellm_config.yaml --port 7860 --num_workers 4
