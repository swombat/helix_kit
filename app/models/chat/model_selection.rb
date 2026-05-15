module Chat::ModelSelection

  extend ActiveSupport::Concern

  # Available AI models grouped by category
  # Model IDs from OpenRouter API: https://openrouter.ai/api/v1/models
  # provider_model_id: the model ID used when calling the provider's direct API
  MODELS = [
    # Top Models - Flagship from each major provider
    {
      model_id: "openai/gpt-5.5",
      label: "GPT-5.5",
      group: "Top Models",
      provider_model_id: "gpt-5.5",
      thinking: { supported: true }
    },
    {
      model_id: "openai/gpt-5.4",
      label: "GPT-5.4",
      group: "Top Models",
      provider_model_id: "gpt-5.4",
      thinking: { supported: true }
    },
    {
      model_id: "anthropic/claude-opus-4.7",
      label: "Claude Opus 4.7",
      group: "Top Models",
      provider_model_id: "claude-opus-4-7",
      thinking: { supported: true, requires_direct_api: true }
    },
    {
      model_id: "anthropic/claude-opus-4.6",
      label: "Claude Opus 4.6",
      group: "Top Models",
      provider_model_id: "claude-opus-4-6",
      thinking: { supported: true, requires_direct_api: true }
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
      model_id: "x-ai/grok-4.3",
      label: "Grok 4.3",
      group: "Top Models",
      provider_model_id: "grok-4.3",
      thinking: { supported: true }
    },
    { model_id: "deepseek/deepseek-v3.2", label: "DeepSeek V3.2", group: "Top Models" },

    # OpenAI
    {
      model_id: "openai/gpt-5.5-pro",
      label: "GPT-5.5 Pro",
      group: "OpenAI",
      provider_model_id: "gpt-5.5-pro",
      thinking: { supported: true, requires_direct_api: true }
    },
    {
      model_id: "openai/gpt-5.2",
      label: "GPT-5.2",
      group: "OpenAI",
      provider_model_id: "gpt-5.2",
      thinking: { supported: true }
    },
    {
      model_id: "openai/gpt-5.1",
      label: "GPT-5.1",
      group: "OpenAI",
      provider_model_id: "gpt-5.1",
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
    {
      model_id: "openai/gpt-4o",
      label: "GPT-4o",
      group: "OpenAI",
      provider_model_id: "gpt-4o"
    },
    {
      model_id: "openai/gpt-4o-mini",
      label: "GPT-4o Mini",
      group: "OpenAI",
      provider_model_id: "gpt-4o-mini"
    },

    # Anthropic
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

    # xAI - Grok models with reasoning support
    # grok-4.3/4.20: Support configurable reasoning on the direct xAI API
    # grok-4/grok-3: Built-in reasoning but not exposed/configurable
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
    {
      model_id: "deepseek/deepseek-v4-flash",
      label: "DeepSeek V4 Flash",
      group: "DeepSeek",
      provider_model_id: "deepseek-v4-flash"
    },
    { model_id: "deepseek/deepseek-r1", label: "DeepSeek R1", group: "DeepSeek" },
    { model_id: "deepseek/deepseek-v3", label: "DeepSeek V3", group: "DeepSeek" }
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
