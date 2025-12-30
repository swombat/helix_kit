# frozen_string_literal: true

# Determines the correct LLM provider based on model ID.
#
# Gemini models (google/*) need direct API access for tool calling to work
# due to thought_signature requirements. All other models go through OpenRouter.
#
# See: config/initializers/01_gemini_thought_signature_patch.rb
module SelectsLlmProvider

  extend ActiveSupport::Concern

  private

  # Returns the provider and normalized model ID for a given model
  #
  # @param model_id [String] The model ID (e.g., "google/gemini-2.5-pro" or "anthropic/claude-3.5-sonnet")
  # @return [Hash] { provider: Symbol, model_id: String }
  def llm_provider_for(model_id)
    if gemini_model?(model_id) && gemini_direct_access_enabled?
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

  # Check if this is a Gemini model that needs direct API access
  def gemini_model?(model_id)
    model_id.to_s.start_with?("google/")
  end

  # Check if direct Gemini access is properly configured
  # Falls back to OpenRouter if not configured
  def gemini_direct_access_enabled?
    return @gemini_enabled if defined?(@gemini_enabled)

    # Check if Gemini API key is configured
    gemini_key = RubyLLM.config.gemini_api_key
    key_configured = gemini_key.present? && !gemini_key.start_with?("<")

    # Check if metadata column exists on ToolCall (required for thought_signature)
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

  # Convert OpenRouter model ID to direct Gemini model ID
  # "google/gemini-2.5-pro" -> "gemini-2.5-pro"
  def normalize_gemini_model_id(model_id)
    model_id.to_s.sub(/^google\//, "")
  end

end
