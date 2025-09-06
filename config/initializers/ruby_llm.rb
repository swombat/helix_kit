RubyLLM.configure do |config|
  config.openai_api_key = Rails.application.credentials.dig(:ai, :open_ai, :api_token) || ENV["OPENAI_API_KEY"] || "<OPENAI_API_KEY>"
  config.anthropic_api_key = Rails.application.credentials.dig(:ai, :claude, :api_token) || ENV["ANTHROPIC_API_KEY"] || "<ANTHROPIC_API_KEY>"
  config.openrouter_api_key = Rails.application.credentials.dig(:ai, :openrouter, :api_token) || ENV["OPENROUTER_API_KEY"] || "<OPENROUTER_API_KEY>"

  config.default_model = "openrouter/auto"
end
