module Chat::ModelSelection

  extend ActiveSupport::Concern

  # Available AI models grouped by category
  # Model IDs from OpenRouter API: https://openrouter.ai/api/v1/models
  # provider_model_id: the model ID used when calling the provider's direct API
  MODELS = [
    # Top Models - Flagship from each major provider
    {
      model_id: "openai/gpt-5.6-sol",
      label: "GPT-5.6 Sol",
      group: "Top Models",
      provider_model_id: "gpt-5.6-sol",
      thinking: { supported: true }
    },
    {
      model_id: "anthropic/claude-fable-5",
      label: "Claude Fable 5",
      group: "Top Models",
      provider_model_id: "claude-fable-5"
    },
    {
      model_id: "deepseek/deepseek-v4-pro",
      label: "DeepSeek V4 Pro",
      group: "Top Models",
      provider_model_id: "deepseek-v4-pro",
      thinking: { supported: true, requires_direct_api: true }
    },
    {
      model_id: "google/gemini-3.1-pro-preview",
      label: "Gemini 3.1 Pro",
      group: "Top Models",
      provider_model_id: "gemini-3.1-pro-preview",
      thinking: { supported: true },
      audio_input: true
    },
    {
      model_id: "x-ai/grok-4.5",
      label: "Grok 4.5",
      group: "Top Models",
      provider_model_id: "grok-4.5"
    },
    { model_id: "mistralai/mistral-large-2512", label: "Mistral Large 2512", group: "Top Models" },
    { model_id: "meta-llama/llama-4-maverick", label: "Llama 4 Maverick", group: "Top Models" },
    { model_id: "minimax/minimax-m3", label: "MiniMax M3", group: "Top Models", thinking: { supported: true } },
    { model_id: "moonshotai/kimi-k2.7-code", label: "Kimi K2.7 Code", group: "Top Models" },
    { model_id: "qwen/qwen3.7-max", label: "Qwen3.7 Max", group: "Top Models", thinking: { supported: true } },
    { model_id: "z-ai/glm-5.2", label: "GLM 5.2", group: "Top Models", thinking: { supported: true } },

    # OpenAI
    { model_id: "openai/gpt-5.6-sol", label: "GPT-5.6 Sol", group: "OpenAI", provider_model_id: "gpt-5.6-sol", thinking: { supported: true } },
    { model_id: "openai/gpt-5.6-terra", label: "GPT-5.6 Terra", group: "OpenAI", provider_model_id: "gpt-5.6-terra", thinking: { supported: true } },
    { model_id: "openai/gpt-5.6-luna", label: "GPT-5.6 Luna", group: "OpenAI", provider_model_id: "gpt-5.6-luna", thinking: { supported: true } },
    { model_id: "openai/gpt-5.5", label: "GPT-5.5", group: "OpenAI", provider_model_id: "gpt-5.5", thinking: { supported: true } },
    {
      model_id: "openai/gpt-5.5-pro",
      label: "GPT-5.5 Pro",
      group: "OpenAI",
      provider_model_id: "gpt-5.5-pro",
      thinking: { supported: true, requires_direct_api: true }
    },
    { model_id: "openai/gpt-5.4", label: "GPT-5.4", group: "OpenAI", provider_model_id: "gpt-5.4", thinking: { supported: true } },
    {
      model_id: "openai/gpt-5.2",
      label: "GPT-5.2",
      group: "OpenAI",
      provider_model_id: "gpt-5.2",
      thinking: { supported: true }
    },
    { model_id: "openai/gpt-5.4-mini", label: "GPT-5.4 Mini", group: "OpenAI", provider_model_id: "gpt-5.4-mini", thinking: { supported: true } },
    { model_id: "openai/gpt-5.4-nano", label: "GPT-5.4 Nano", group: "OpenAI", provider_model_id: "gpt-5.4-nano", thinking: { supported: true } },
    {
      model_id: "openai/gpt-5.3-chat",
      label: "GPT-5.3 Chat",
      group: "OpenAI",
      thinking: { supported: true }
    },
    {
      model_id: "openai/gpt-5.3-codex",
      label: "GPT-5.3 Codex",
      group: "OpenAI",
      thinking: { supported: true }
    },
    {
      model_id: "openai/gpt-5.2-codex",
      label: "GPT-5.2 Codex",
      group: "OpenAI",
      thinking: { supported: true }
    },
    {
      model_id: "openai/gpt-5.1",
      label: "GPT-5.1",
      group: "OpenAI",
      provider_model_id: "gpt-5.1",
      thinking: { supported: true }
    },
    { model_id: "openai/gpt-5.1-codex-max", label: "GPT-5.1 Codex Max", group: "OpenAI", provider_model_id: "gpt-5.1-codex-max", thinking: { supported: true } },
    { model_id: "openai/gpt-5.1-codex-mini", label: "GPT-5.1 Codex Mini", group: "OpenAI", provider_model_id: "gpt-5.1-codex-mini", thinking: { supported: true } },
    {
      model_id: "openai/gpt-5.1-codex",
      label: "GPT-5.1 Codex",
      group: "OpenAI",
      thinking: { supported: true }
    },
    {
      model_id: "openai/gpt-5",
      label: "GPT-5",
      group: "OpenAI",
      provider_model_id: "gpt-5",
      thinking: { supported: true }
    },
    {
      model_id: "openai/gpt-5-codex",
      label: "GPT-5 Codex",
      group: "OpenAI",
      thinking: { supported: true }
    },
    {
      model_id: "openai/gpt-5-mini",
      label: "GPT-5 Mini",
      group: "OpenAI",
      provider_model_id: "gpt-5-mini"
    },
    {
      model_id: "openai/gpt-5-nano",
      label: "GPT-5 Nano",
      group: "OpenAI",
      provider_model_id: "gpt-5-nano"
    },
    {
      model_id: "openai/o3",
      label: "O3",
      group: "OpenAI",
      provider_model_id: "o3"
    },
    {
      model_id: "openai/o3-mini",
      label: "O3 Mini",
      group: "OpenAI",
      provider_model_id: "o3-mini"
    },
    { model_id: "openai/o4-mini-high", label: "O4 Mini High", group: "OpenAI" },
    {
      model_id: "openai/o4-mini",
      label: "O4 Mini",
      group: "OpenAI",
      provider_model_id: "o4-mini"
    },
    {
      model_id: "openai/o1",
      label: "O1",
      group: "OpenAI",
      provider_model_id: "o1"
    },
    {
      model_id: "openai/gpt-4.1",
      label: "GPT-4.1",
      group: "OpenAI",
      provider_model_id: "gpt-4.1"
    },
    {
      model_id: "openai/gpt-4.1-mini",
      label: "GPT-4.1 Mini",
      group: "OpenAI",
      provider_model_id: "gpt-4.1-mini"
    },
    { model_id: "openai/gpt-4.1-nano", label: "GPT-4.1 Nano", group: "OpenAI" },
    { model_id: "openai/gpt-4-turbo", label: "GPT-4 Turbo", group: "OpenAI" },
    { model_id: "openai/gpt-4", label: "GPT-4", group: "OpenAI" },
    { model_id: "openai/gpt-3.5-turbo", label: "GPT-3.5 Turbo", group: "OpenAI" },
    {
      model_id: "openai/gpt-4o",
      label: "GPT-4o",
      group: "OpenAI",
      provider_model_id: "gpt-4o"
    },
    {
      model_id: "openai/gpt-4o-2024-08-06",
      label: "GPT-4o (2024-08-06)",
      group: "OpenAI"
    },
    {
      model_id: "openai/gpt-4o-mini",
      label: "GPT-4o Mini",
      group: "OpenAI",
      provider_model_id: "gpt-4o-mini"
    },
    { model_id: "openai/gpt-oss-120b", label: "GPT-OSS 120B", group: "OpenAI" },
    { model_id: "openai/gpt-oss-20b", label: "GPT-OSS 20B", group: "OpenAI" },

    # Anthropic
    {
      model_id: "anthropic/claude-sonnet-5",
      label: "Claude Sonnet 5",
      group: "Anthropic",
      provider_model_id: "claude-sonnet-5",
      thinking: { supported: true, requires_direct_api: true }
    },
    {
      model_id: "anthropic/claude-fable-5",
      label: "Claude Fable 5",
      group: "Anthropic",
      provider_model_id: "claude-fable-5"
    },
    {
      model_id: "anthropic/claude-opus-4.8",
      label: "Claude Opus 4.8",
      group: "Anthropic",
      provider_model_id: "claude-opus-4-8",
      thinking: { supported: true, requires_direct_api: true }
    },
    {
      model_id: "anthropic/claude-opus-4.7",
      label: "Claude Opus 4.7",
      group: "Anthropic",
      provider_model_id: "claude-opus-4-7",
      thinking: { supported: true, requires_direct_api: true }
    },
    {
      model_id: "anthropic/claude-opus-4.6",
      label: "Claude Opus 4.6",
      group: "Anthropic",
      provider_model_id: "claude-opus-4-6",
      thinking: { supported: true, requires_direct_api: true }
    },
    {
      model_id: "anthropic/claude-opus-4.5",
      label: "Claude Opus 4.5",
      group: "Anthropic",
      provider_model_id: "claude-opus-4-5-20251101",
      thinking: { supported: true, requires_direct_api: true }
    },
    {
      model_id: "anthropic/claude-sonnet-4.5",
      label: "Claude Sonnet 4.5",
      group: "Anthropic",
      provider_model_id: "claude-sonnet-4-5-20250929",
      thinking: { supported: true, requires_direct_api: true }
    },
    {
      model_id: "anthropic/claude-sonnet-4.6",
      label: "Claude Sonnet 4.6",
      group: "Anthropic"
    },
    {
      model_id: "anthropic/claude-haiku-4.5",
      label: "Claude Haiku 4.5",
      group: "Anthropic",
      provider_model_id: "claude-haiku-4-5-20251001"
    },
    {
      model_id: "anthropic/claude-opus-4.1",
      label: "Claude Opus 4.1",
      group: "Anthropic",
      provider_model_id: "claude-opus-4-1-20250805",
      thinking: { supported: true, requires_direct_api: true }
    },
    {
      model_id: "anthropic/claude-opus-4",
      label: "Claude Opus 4",
      group: "Anthropic",
      provider_model_id: "claude-opus-4-20250514",
      thinking: { supported: true, requires_direct_api: true }
    },
    {
      model_id: "anthropic/claude-sonnet-4",
      label: "Claude Sonnet 4",
      group: "Anthropic",
      provider_model_id: "claude-sonnet-4-20250514",
      thinking: { supported: true, requires_direct_api: true }
    },
    {
      model_id: "anthropic/claude-3.7-sonnet",
      label: "Claude 3.7 Sonnet",
      group: "Anthropic",
      provider_model_id: "claude-3-7-sonnet-latest",
      thinking: { supported: true }
    },
    {
      model_id: "anthropic/claude-3.5-sonnet",
      label: "Claude 3.5 Sonnet",
      group: "Anthropic",
      provider_model_id: "claude-3-5-sonnet-latest"
    },
    {
      model_id: "anthropic/claude-3-opus",
      label: "Claude 3 Opus",
      group: "Anthropic",
      provider_model_id: "claude-3-opus-latest"
    },

    # Google
    {
      model_id: "google/gemini-3.1-pro-preview",
      label: "Gemini 3.1 Pro",
      group: "Google",
      provider_model_id: "gemini-3.1-pro-preview",
      thinking: { supported: true },
      audio_input: true
    },
    {
      model_id: "google/gemini-3.5-flash",
      label: "Gemini 3.5 Flash",
      group: "Google",
      provider_model_id: "gemini-3.5-flash",
      thinking: { supported: true },
      audio_input: true
    },
    {
      model_id: "google/gemini-3.1-flash-lite",
      label: "Gemini 3.1 Flash Lite",
      group: "Google",
      provider_model_id: "gemini-3.1-flash-lite",
      thinking: { supported: true },
      audio_input: true
    },
    {
      model_id: "google/gemini-3-pro-preview",
      label: "Gemini 3 Pro",
      group: "Google",
      provider_model_id: "gemini-3-pro-preview",
      thinking: { supported: true },
      audio_input: true
    },
    {
      model_id: "google/gemini-3-flash-preview",
      label: "Gemini 3 Flash",
      group: "Google",
      provider_model_id: "gemini-3-flash-preview",
      audio_input: true
    },
    {
      model_id: "google/gemini-2.5-pro",
      label: "Gemini 2.5 Pro",
      group: "Google",
      provider_model_id: "gemini-2.5-pro",
      audio_input: true
    },
    {
      model_id: "google/gemini-2.5-flash",
      label: "Gemini 2.5 Flash",
      group: "Google",
      provider_model_id: "gemini-2.5-flash",
      audio_input: true
    },
    {
      model_id: "google/gemini-2.5-flash-lite",
      label: "Gemini 2.5 Flash Lite",
      group: "Google",
      provider_model_id: "gemini-2.5-flash-lite",
      thinking: { supported: true },
      audio_input: true
    },
    {
      model_id: "google/gemini-2.0-flash-001",
      label: "Gemini 2.0 Flash",
      group: "Google",
      provider_model_id: "gemini-2.0-flash-001",
      audio_input: true
    },
    {
      model_id: "google/gemini-2.0-flash-lite-001",
      label: "Gemini 2.0 Flash Lite",
      group: "Google",
      provider_model_id: "gemini-2.0-flash-lite-001",
      audio_input: true
    },
    {
      model_id: "google/gemma-4-31b-it",
      label: "Gemma 4 31B",
      group: "Google",
      provider_model_id: "gemma-4-31b-it",
      thinking: { supported: true }
    },
    {
      model_id: "google/gemma-4-26b-a4b-it",
      label: "Gemma 4 26B A4B",
      group: "Google",
      provider_model_id: "gemma-4-26b-a4b-it",
      thinking: { supported: true }
    },

    # xAI - Grok models
    # grok-4.3/4.20: Support configurable reasoning on the direct xAI API
    # grok-4/grok-3: Built-in reasoning but not exposed/configurable
    {
      model_id: "x-ai/grok-4.5",
      label: "Grok 4.5",
      group: "xAI",
      provider_model_id: "grok-4.5"
    },
    {
      model_id: "x-ai/grok-4.3",
      label: "Grok 4.3",
      group: "xAI",
      provider_model_id: "grok-4.3",
      thinking: { supported: true }
    },
    {
      model_id: "x-ai/grok-4.20",
      label: "Grok 4.20",
      group: "xAI",
      provider_model_id: "grok-4.20-0309-reasoning",
      thinking: { supported: true }
    },
    {
      model_id: "x-ai/grok-4.20-non-reasoning",
      label: "Grok 4.20 Non-Reasoning",
      group: "xAI",
      provider_model_id: "grok-4.20-0309-non-reasoning"
    },
    {
      model_id: "x-ai/grok-build-0.1",
      label: "GrokBuild 0.1",
      group: "xAI",
      provider_model_id: "grok-build-0.1"
    },
    {
      model_id: "x-ai/grok-4.2",
      label: "Grok 4.2",
      group: "xAI",
      provider_model_id: "grok-4.2",
      thinking: { supported: true }
    },
    {
      model_id: "x-ai/grok-4-1-fast-reasoning",
      label: "Grok 4.1 Fast Reasoning",
      group: "xAI",
      provider_model_id: "grok-4-1-fast-reasoning",
      thinking: { supported: true }
    },
    {
      model_id: "x-ai/grok-4-1-fast-non-reasoning",
      label: "Grok 4.1 Fast Non-Reasoning",
      group: "xAI",
      provider_model_id: "grok-4-1-fast-non-reasoning"
    },
    {
      model_id: "x-ai/grok-4.20-multi-agent",
      label: "Grok 4.20 Multi-Agent",
      group: "xAI",
      provider_model_id: "grok-4.20-multi-agent-0309",
      thinking: { supported: true }
    },
    {
      model_id: "x-ai/grok-3-mini",
      label: "Grok 3 Mini",
      group: "xAI",
      provider_model_id: "grok-3-mini",
      thinking: { supported: true }
    },
    {
      model_id: "x-ai/grok-4-fast",
      label: "Grok 4 Fast",
      group: "xAI",
      provider_model_id: "grok-4-fast",
      thinking: { supported: true }
    },
    {
      model_id: "x-ai/grok-4",
      label: "Grok 4",
      group: "xAI",
      provider_model_id: "grok-4"
    },
    {
      model_id: "x-ai/grok-3",
      label: "Grok 3",
      group: "xAI",
      provider_model_id: "grok-3"
    },

    # DeepSeek
    { model_id: "deepseek/deepseek-chat", label: "DeepSeek Chat", group: "DeepSeek" },
    { model_id: "deepseek/deepseek-v3.2", label: "DeepSeek V3.2", group: "DeepSeek" },
    {
      model_id: "deepseek/deepseek-v4-flash",
      label: "DeepSeek V4 Flash",
      group: "DeepSeek",
      provider_model_id: "deepseek-v4-flash"
    },
    { model_id: "deepseek/deepseek-r1", label: "DeepSeek R1", group: "DeepSeek" },
    { model_id: "deepseek/deepseek-v3", label: "DeepSeek V3", group: "DeepSeek" },

    # Moonshot / Kimi
    { model_id: "moonshotai/kimi-k2.7-code", label: "Kimi K2.7 Code", group: "Moonshot / Kimi" },
    { model_id: "moonshotai/kimi-coding", label: "Kimi Coding", group: "Moonshot / Kimi" },
    { model_id: "moonshotai/kimi-k2.6", label: "Kimi K2.6", group: "Moonshot / Kimi", thinking: { supported: true } },
    { model_id: "moonshotai/kimi-k2.5", label: "Kimi K2.5", group: "Moonshot / Kimi", thinking: { supported: true } },
    { model_id: "moonshotai/kimi-k2-thinking", label: "Kimi K2 Thinking", group: "Moonshot / Kimi", thinking: { supported: true } },
    { model_id: "moonshotai/kimi-k2-0905", label: "Kimi K2 0905", group: "Moonshot / Kimi" },

    # MiniMax
    { model_id: "minimax/minimax-m3", label: "MiniMax M3", group: "MiniMax", thinking: { supported: true } },
    { model_id: "minimax/minimax-m2.7", label: "MiniMax M2.7", group: "MiniMax", thinking: { supported: true } },
    { model_id: "minimax/minimax-m2", label: "MiniMax M2", group: "MiniMax", thinking: { supported: true } },

    # Mistral
    { model_id: "mistralai/devstral-2512", label: "Devstral 2512", group: "Mistral" },
    { model_id: "mistralai/codestral-2508", label: "Codestral 2508", group: "Mistral" },
    { model_id: "mistralai/mistral-large-2512", label: "Mistral Large 2512", group: "Mistral" },
    { model_id: "mistralai/mistral-medium-3-5", label: "Mistral Medium 3.5", group: "Mistral" },
    { model_id: "mistralai/mistral-medium-3.1", label: "Mistral Medium 3.1", group: "Mistral" },
    { model_id: "mistralai/mistral-medium-3", label: "Mistral Medium 3", group: "Mistral" },
    { model_id: "mistralai/mistral-small-2603", label: "Mistral Small 2603", group: "Mistral" },
    { model_id: "mistralai/mistral-small-3.2-24b-instruct", label: "Mistral Small 3.2 24B Instruct", group: "Mistral" },
    { model_id: "mistralai/mistral-small-3.1-24b-instruct", label: "Mistral Small 3.1 24B Instruct", group: "Mistral" },
    { model_id: "mistralai/mistral-small-24b-instruct-2501", label: "Mistral Small 24B Instruct 2501", group: "Mistral" },
    { model_id: "mistralai/ministral-14b-2512", label: "Ministral 14B 2512", group: "Mistral" },
    { model_id: "mistralai/ministral-8b-2512", label: "Ministral 8B 2512", group: "Mistral" },
    { model_id: "mistralai/ministral-3b-2512", label: "Ministral 3B 2512", group: "Mistral" },
    { model_id: "mistralai/mistral-nemo", label: "Mistral Nemo", group: "Mistral" },
    { model_id: "mistralai/mistral-saba", label: "Mistral Saba", group: "Mistral" },
    { model_id: "mistralai/mixtral-8x22b-instruct", label: "Mixtral 8x22B Instruct", group: "Mistral" },

    # Meta Llama
    { model_id: "meta-llama/llama-4-maverick", label: "Llama 4 Maverick", group: "Meta Llama" },
    { model_id: "meta-llama/llama-4-scout", label: "Llama 4 Scout", group: "Meta Llama" },
    { model_id: "meta-llama/llama-3.3-70b-instruct", label: "Llama 3.3 70B Instruct", group: "Meta Llama" },
    { model_id: "meta-llama/llama-3.1-70b-instruct", label: "Llama 3.1 70B Instruct", group: "Meta Llama" },
    { model_id: "meta-llama/llama-3.1-8b-instruct", label: "Llama 3.1 8B Instruct", group: "Meta Llama" },
    { model_id: "meta-llama/llama-3.2-1b-instruct", label: "Llama 3.2 1B Instruct", group: "Meta Llama" },
    { model_id: "meta-llama/llama-3.2-3b-instruct", label: "Llama 3.2 3B Instruct", group: "Meta Llama" },
    { model_id: "meta-llama/llama-3.2-11b-vision-instruct", label: "Llama 3.2 11B Vision Instruct", group: "Meta Llama" },

    # Qwen
    { model_id: "qwen/qwen3.7-max", label: "Qwen3.7 Max", group: "Qwen", thinking: { supported: true } },
    { model_id: "qwen/qwen3.6-plus", label: "Qwen3.6 Plus", group: "Qwen", thinking: { supported: true } },
    { model_id: "qwen/qwen3.6-max-preview", label: "Qwen3.6 Max Preview", group: "Qwen", thinking: { supported: true } },
    { model_id: "qwen/qwen3.6-flash", label: "Qwen3.6 Flash", group: "Qwen", thinking: { supported: true } },
    { model_id: "qwen/qwen3.5-plus-20260420", label: "Qwen3.5 Plus (2026-04-20)", group: "Qwen", thinking: { supported: true } },
    { model_id: "qwen/qwen3.5-flash-02-23", label: "Qwen3.5 Flash (02-23)", group: "Qwen", thinking: { supported: true } },
    { model_id: "qwen/qwen3-max-thinking", label: "Qwen3 Max Thinking", group: "Qwen", thinking: { supported: true } },
    { model_id: "qwen/qwen3-max", label: "Qwen3 Max", group: "Qwen" },
    { model_id: "qwen/qwen3-coder-flash", label: "Qwen3 Coder Flash", group: "Qwen" },
    { model_id: "qwen/qwen3-coder-plus", label: "Qwen3 Coder Plus", group: "Qwen" },

    # Z.ai
    { model_id: "z-ai/glm-5.2", label: "GLM 5.2", group: "Z.ai", thinking: { supported: true } },
    { model_id: "z-ai/glm-5.1", label: "GLM 5.1", group: "Z.ai", thinking: { supported: true } },
    { model_id: "z-ai/glm-5.1-coding", label: "GLM 5.1 Coding", group: "Z.ai", thinking: { supported: true } },
    { model_id: "z-ai/glm-4.7", label: "GLM 4.7", group: "Z.ai", thinking: { supported: true } },
    { model_id: "z-ai/glm-4.6", label: "GLM 4.6", group: "Z.ai", thinking: { supported: true } },
    { model_id: "z-ai/glm-4.6-coding", label: "GLM 4.6 Coding", group: "Z.ai", thinking: { supported: true } },
    { model_id: "z-ai/glm-4.5", label: "GLM 4.5", group: "Z.ai", thinking: { supported: true } }
  ].freeze

  included do
    const_set(:MODELS, MODELS) unless const_defined?(:MODELS, false)
  end

  class_methods do
    def model_config(model_id)
      Chat::ModelSelection::MODELS.find { |m| m[:model_id] == model_id }
    end

    def supports_thinking?(model_id)
      model_config(model_id)&.dig(:thinking, :supported) == true
    end

    def supports_audio_input?(model_id)
      model_config(model_id)&.dig(:audio_input) == true
    end

    def supports_pdf_input?(model_id)
      # xAI's API doesn't support PDF file attachments (no 'file' content type).
      # For these providers, PDFs are extracted to text before sending.
      !model_id.start_with?("x-ai/")
    end

    def requires_direct_api_for_thinking?(model_id)
      model_config(model_id)&.dig(:thinking, :requires_direct_api) == true
    end

    def provider_model_id(model_id)
      config = model_config(model_id)
      config&.dig(:provider_model_id) || config&.dig(:thinking, :provider_model_id) || model_id.to_s.sub(%r{^.+/}, "")
    end

    def resolve_provider(model_id)
      ResolvesProvider.resolve_provider(model_id)
    end
  end

  # Override RubyLLM's model_id getter to return the string value
  # (RubyLLM's version returns ai_model&.model_id which is nil before save)
  def model_id
    model_id_string_value
  end

  def model_label
    model = self.class.model_config(model_id_string_value)
    model ? model[:label] : model_id_string_value
  end

  # Returns the friendly model name, or nil if not found in MODELS list
  def ai_model_name
    model = self.class.model_config(model_id_string_value)
    model&.dig(:label)
  end

  # Get the model_id string from either the pending value, association, or legacy column
  def model_id_string_value
    @model_string || ai_model&.model_id || model_id_string
  end

end
