require "test_helper"

class AgentInteractionCostReportTest < ActiveSupport::TestCase

  setup do
    @agent = agents(:research_assistant)
  end

  test "groups available estimates by day with the latest day first" do
    create_interaction!(started_at: Time.zone.local(2026, 7, 20, 10))
    create_interaction!(started_at: Time.zone.local(2026, 7, 22, 9))
    create_interaction!(started_at: Time.zone.local(2026, 7, 22, 15))
    create_interaction!(
      started_at: Time.zone.local(2026, 7, 21, 12),
      telemetry_schema_version: nil,
      usage_scope: nil
    )

    report = AgentInteractionCostReport.new(agent: @agent).call

    assert_equal [ "2026-07-22", "2026-07-20" ], report[:days].pluck(:date)
    assert_equal "0.0045", report.dig(:days, 0, :amount_usd)
    assert_equal 2, report.dig(:days, 0, :interaction_count)
    assert_equal "0.00675", report[:total_amount_usd]
    assert_equal 3, report[:interaction_count]
  end

  test "returns no total when no estimates are available" do
    create_interaction!(
      started_at: Time.zone.local(2026, 7, 22, 9),
      telemetry_schema_version: nil,
      usage_scope: nil
    )

    report = AgentInteractionCostReport.new(agent: @agent).call

    assert_nil report[:total_amount_usd]
    assert_empty report[:days]
  end

  test "limits the displayed table to the latest thirty cost days" do
    31.times do |index|
      create_interaction!(started_at: Time.zone.local(2026, 7, 22, 12) - index.days)
    end

    report = AgentInteractionCostReport.new(agent: @agent).call

    assert_equal 30, report[:days].size
    assert_equal "2026-07-22", report.dig(:days, 0, :date)
    assert_equal "2026-06-23", report.dig(:days, 29, :date)
    assert_equal "0.06975", report[:total_amount_usd]
    assert_equal 31, report[:interaction_count]
  end

  private

  def create_interaction!(**attributes)
    AgentRuntimeInteraction.create!(
      {
        agent: @agent,
        trigger_kind: "wake",
        started_at: Time.current,
        telemetry_schema_version: 1,
        usage_scope: "trigger",
        usage_complete: true,
        provider: "anthropic",
        model: "claude-sonnet-5",
        uncached_input_tokens: 1_000,
        cache_creation_input_tokens: 0,
        cache_read_input_tokens: 0,
        output_tokens: 25
      }.merge(attributes)
    )
  end

end
