RubyLLM.configure do |config|
  config.openai_api_key = Rails.application.credentials.dig(:ai, :open_ai, :api_token) || ENV["OPENAI_API_KEY"] || "<OPENAI_API_KEY>"
  config.anthropic_api_key = Rails.application.credentials.dig(:ai, :claude, :api_token) || ENV["ANTHROPIC_API_KEY"] || "<ANTHROPIC_API_KEY>"
  config.openrouter_api_key = Rails.application.credentials.dig(:ai, :openrouter, :api_token) || ENV["OPENROUTER_API_KEY"] || "<OPENROUTER_API_KEY>"
  config.gemini_api_key = Rails.application.credentials.dig(:ai, :gemini, :api_token) || ENV["GEMINI_API_KEY"] || "<GEMINI_API_KEY>"
  config.xai_api_key = Rails.application.credentials.dig(:ai, :xai, :api_token) || ENV["XAI_API_KEY"] || "<XAI_API_KEY>"

  config.default_model = "openrouter/auto"

  # Use new model registry for RubyLLM 1.9+
  config.use_new_acts_as = true
  config.model_registry_class = "AiModel"
end
