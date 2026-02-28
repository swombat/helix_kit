# frozen_string_literal: true

# Determines the correct LLM provider based on model ID and configuration.
#
# Routes to direct provider APIs (Anthropic, OpenAI, Gemini, xAI) when API keys
# are available. Falls back to OpenRouter for unconfigured providers (e.g., DeepSeek).
#
# Gemini has an additional requirement: the tool_calls table must have a metadata
# column (needed for thought_signature storage with tool-calling jobs).
module SelectsLlmProvider

  extend ActiveSupport::Concern

  private

  # Returns the provider and normalized model ID for a given model
  #
  # @param model_id [String] The model ID (e.g., "anthropic/claude-opus-4.6")
  # @param thinking_enabled [Boolean] Whether thinking is enabled (retained for caller compatibility)
  # @return [Hash] { provider: Symbol, model_id: String }
  def llm_provider_for(model_id, thinking_enabled: false)
    config = ResolvesProvider.resolve_provider(model_id)

    # Gemini requires metadata column on tool_calls for tool-calling jobs
    if config[:provider] == :gemini && !gemini_metadata_column_exists?
      Rails.logger.warn "[SelectsLlmProvider] Direct Gemini access disabled: metadata column missing from tool_calls. Falling back to OpenRouter."
      return { provider: :openrouter, model_id: model_id }
    end

    config
  end

  def gemini_metadata_column_exists?
    return @gemini_metadata_exists if defined?(@gemini_metadata_exists)
    @gemini_metadata_exists = ToolCall.column_names.include?("metadata")
  end

  # Used directly by ManualAgentResponseJob and AllAgentsResponseJob
  # to check Anthropic API availability before attempting thinking mode.
  def anthropic_api_available?
    ResolvesProvider.api_key_available?(:anthropic)
  end

end
