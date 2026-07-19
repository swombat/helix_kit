# frozen_string_literal: true

# =============================================================================
# ANTHROPIC ADAPTIVE THINKING MONKEY PATCH
# =============================================================================
#
# Claude Opus 4.7 (and presumably newer Anthropic thinking models) replaced the
# `thinking: { type: "enabled", budget_tokens: N }` shape with an adaptive shape:
#
#   thinking: { type: "adaptive" }
#   output_config: { effort: "low"|"medium"|"high" }
#
# Sending the old shape returns:
#   "thinking.type.enabled is not supported for this model. Use
#    thinking.type.adaptive and output_config.effort to control thinking behavior."
#
# RubyLLM 1.16 supports both shapes when its model registry includes reasoning
# options. HelixKit's persisted AiModel rows can predate those fields, though,
# so this patch supplies the known model-specific behavior while the registry
# catches up.
#
# REMOVE WHEN: RubyLLM ships native adaptive thinking support for Anthropic.
# =============================================================================

if defined?(RubyLLM::Providers::Anthropic)
  module AnthropicAdaptiveThinkingPatch

    ADAPTIVE_MODELS = %w[
      claude-opus-4-8
      claude-opus-4-7
    ].freeze

    def build_thinking_payload(thinking, model)
      return super unless thinking&.enabled?
      return adaptive_thinking_payload(adaptive_effort_for(thinking)) if ADAPTIVE_MODELS.include?(model.id)

      super
    rescue ArgumentError => error
      raise unless stale_reasoning_metadata?(error, model, thinking)

      enabled_thinking_payload(thinking.budget)
    end

    private

    def stale_reasoning_metadata?(error, model, thinking)
      thinking.budget.is_a?(Integer) &&
        error.message == "Anthropic thinking budget is not supported for #{model.id}"
    end

    def adaptive_effort_for(thinking)
      budget = thinking.respond_to?(:budget) ? thinking.budget : nil
      case budget
      when nil, 0..2_000 then "low"
      when 2_001..10_000 then "medium"
      else "high"
      end
    end

  end

  RubyLLM::Providers::Anthropic.prepend(AnthropicAdaptiveThinkingPatch)
  Rails.logger.info "[RubyLLM] Anthropic adaptive thinking patch applied"
end
