require "test_helper"

class AgentRuntimeInteractionCostTest < ActiveSupport::TestCase

  test "estimates direct Anthropic cost with one hour cache pricing" do
    interaction = build_interaction(
      provider: "anthropic",
      model: "claude-fable-5",
      cache_ttl: "1h",
      uncached_input_tokens: 100_000,
      cache_creation_input_tokens: 20_000,
      cache_read_input_tokens: 500_000,
      output_tokens: 10_000,
      reasoning_output_tokens: 2_000
    )

    cost = interaction.estimated_cost

    assert_equal "estimated", cost[:status]
    assert_equal "direct_api", cost[:pricing_source]
    assert_equal "anthropic/claude-fable-5", cost[:pricing_model]
    assert_equal "2026-07-22", cost[:pricing_as_of]
    assert_equal "2.4", cost[:amount_usd]
    assert_equal "0.4", cost.dig(:components_usd, :cache_creation_input)
    assert_equal "0.5", cost.dig(:components_usd, :cache_read_input)
  end

  test "uses OpenRouter pricing source for routed models" do
    interaction = build_interaction(
      provider: "openrouter",
      model: "deepseek/deepseek-v4-pro",
      uncached_input_tokens: 1_000_000,
      cache_creation_input_tokens: 0,
      cache_read_input_tokens: 0,
      output_tokens: 1_000_000
    )

    cost = interaction.estimated_cost

    assert_equal "openrouter", cost[:pricing_source]
    assert_equal "1.305", cost[:amount_usd]
  end

  test "does not double charge reasoning tokens already included in output" do
    interaction = build_interaction(
      provider: "openai",
      model: "gpt-5.5",
      uncached_input_tokens: 0,
      cache_creation_input_tokens: 0,
      cache_read_input_tokens: 0,
      output_tokens: 100_000,
      reasoning_output_tokens: 80_000
    )

    assert_equal "3.0", interaction.estimated_cost[:amount_usd]
  end

  test "uses model-specific OpenRouter cache rates" do
    interaction = build_interaction(
      provider: "openrouter",
      model: "openai/gpt-4o",
      uncached_input_tokens: 0,
      cache_creation_input_tokens: 0,
      cache_read_input_tokens: 1_000_000,
      output_tokens: 0
    )

    assert_equal "1.25", interaction.estimated_cost[:amount_usd]
  end

  test "leaves cost unavailable for untrusted usage or unknown models" do
    untrusted = build_interaction(
      telemetry_schema_version: nil,
      usage_scope: nil,
      usage_complete: nil,
      provider: "anthropic",
      model: "claude-fable-5"
    )
    unknown = build_interaction(provider: "other", model: "surprise-model")

    assert_nil untrusted.estimated_cost[:amount_usd]
    assert_match(/not trigger-local/, untrusted.estimated_cost[:note])
    assert_nil unknown.estimated_cost[:amount_usd]
    assert_match(/no price/, unknown.estimated_cost[:note])
  end

  private

  def build_interaction(**attributes)
    AgentRuntimeInteraction.new(
      {
        agent: agents(:research_assistant),
        trigger_kind: "conversation",
        started_at: Time.current,
        telemetry_schema_version: 1,
        usage_scope: "trigger",
        usage_complete: true,
        uncached_input_tokens: 0,
        cache_creation_input_tokens: 0,
        cache_read_input_tokens: 0,
        output_tokens: 0
      }.merge(attributes)
    )
  end

end
