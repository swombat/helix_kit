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
# RubyLLM's Anthropic adapter still hardcodes the old shape (build_thinking_payload
# returns { type: 'enabled', budget_tokens: budget }). This patch overrides
# build_base_payload to emit the new shape for models in ADAPTIVE_MODELS.
#
# REMOVE WHEN: RubyLLM ships native adaptive thinking support for Anthropic.
# =============================================================================

if defined?(RubyLLM::Providers::Anthropic)
  module AnthropicAdaptiveThinkingPatch

    ADAPTIVE_MODELS = %w[
      claude-opus-4-7
    ].freeze

    def build_base_payload(chat_messages, model, stream, thinking)
      payload = super
      return payload unless adaptive_thinking?(model, thinking)

      payload[:thinking] = { type: "adaptive" }
      payload[:output_config] = { effort: adaptive_effort_for(thinking) }
      payload.delete(:max_tokens)
      payload
    end

    private

    def adaptive_thinking?(model, thinking)
      ADAPTIVE_MODELS.include?(model.id) && thinking&.enabled?
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
