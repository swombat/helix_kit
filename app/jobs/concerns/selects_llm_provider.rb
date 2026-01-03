# frozen_string_literal: true

# Determines the correct LLM provider based on model ID and configuration.
#
# Routes to appropriate providers:
# - Anthropic direct: for Claude 4+ models with thinking enabled
# - Gemini direct: for Google models (due to thought_signature requirements)
# - OpenRouter: fallback for all other models
module SelectsLlmProvider

  extend ActiveSupport::Concern

  private

  # Returns the provider and normalized model ID for a given model
  #
  # @param model_id [String] The model ID (e.g., "anthropic/claude-opus-4.5")
  # @param thinking_enabled [Boolean] Whether thinking is enabled for this request
  # @return [Hash] { provider: Symbol, model_id: String }
  def llm_provider_for(model_id, thinking_enabled: false)
    if thinking_enabled && Chat.requires_direct_api_for_thinking?(model_id) && anthropic_api_available?
      {
        provider: :anthropic,
        model_id: Chat.provider_model_id(model_id)
      }
    elsif gemini_model?(model_id) && gemini_direct_access_enabled?
      {
        provider: :gemini,
        model_id: normalize_gemini_model_id(model_id)
      }
    else
      {
        provider: :openrouter,
        model_id: model_id
      }
    end
  end

  def anthropic_api_available?
    return @anthropic_available if defined?(@anthropic_available)

    api_key = RubyLLM.config.anthropic_api_key
    @anthropic_available = api_key.present? && !api_key.start_with?("<")

    unless @anthropic_available
      Rails.logger.warn "[SelectsLlmProvider] Anthropic API key not configured"
    end

    @anthropic_available
  end

  def gemini_model?(model_id)
    model_id.to_s.start_with?("google/")
  end

  def gemini_direct_access_enabled?
    return @gemini_enabled if defined?(@gemini_enabled)

    gemini_key = RubyLLM.config.gemini_api_key
    key_configured = gemini_key.present? && !gemini_key.start_with?("<")
    column_exists = ToolCall.column_names.include?("metadata")

    @gemini_enabled = key_configured && column_exists

    unless @gemini_enabled
      reasons = []
      reasons << "Gemini API key not configured" unless key_configured
      reasons << "metadata column missing from tool_calls" unless column_exists
      Rails.logger.warn "[SelectsLlmProvider] Direct Gemini access disabled: #{reasons.join(', ')}. Falling back to OpenRouter."
    end

    @gemini_enabled
  end

  def normalize_gemini_model_id(model_id)
    model_id.to_s.sub(/^google\//, "")
  end

end
