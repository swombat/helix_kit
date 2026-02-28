# frozen_string_literal: true

# Shared logic for routing LLM calls to direct provider APIs when API keys are available.
# Falls back to OpenRouter for providers without configured keys (e.g., DeepSeek).
#
# Used by SelectsLlmProvider (jobs), Chat#to_llm (AiResponseJob), and Prompt (utility calls).
module ResolvesProvider

  module_function

  def resolve_provider(model_id)
    # Only route direct for models with an explicit provider_model_id mapping.
    # This ensures we only use model IDs known to work on direct provider APIs.
    # Models without a mapping (OpenRouter aliases, :thinking suffix, etc.) stay on OpenRouter.
    config = Chat.model_config(model_id)
    direct_model_id = config&.dig(:provider_model_id)
    return { provider: :openrouter, model_id: model_id } unless direct_model_id

    if model_id.start_with?("anthropic/") && api_key_available?(:anthropic)
      { provider: :anthropic, model_id: direct_model_id }
    elsif model_id.start_with?("openai/") && api_key_available?(:openai)
      { provider: :openai, model_id: direct_model_id }
    elsif model_id.start_with?("google/") && api_key_available?(:gemini)
      { provider: :gemini, model_id: direct_model_id }
    elsif model_id.start_with?("x-ai/") && api_key_available?(:xai)
      { provider: :xai, model_id: direct_model_id }
    else
      { provider: :openrouter, model_id: model_id }
    end
  end

  def api_key_available?(provider)
    key = case provider
    when :anthropic then RubyLLM.config.anthropic_api_key
    when :openai then RubyLLM.config.openai_api_key
    when :gemini then RubyLLM.config.gemini_api_key
    when :xai then RubyLLM.config.xai_api_key
    end
    key.present? && !key.start_with?("<")
  end

end
