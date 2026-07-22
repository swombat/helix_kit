require "test_helper"

class AccountInteractionCostReportTest < ActiveSupport::TestCase

  setup do
    @account = accounts(:personal_account)
    @first_agent = agents(:research_assistant)
    @second_agent = @account.agents.create!(
      name: "Second Cost Agent",
      system_prompt: "Track costs",
      model_id: "openrouter/auto"
    )
  end

  test "groups daily costs into agent columns with totals and latest day first" do
    create_interaction!(@first_agent, Time.zone.local(2026, 7, 20, 10))
    create_interaction!(@first_agent, Time.zone.local(2026, 7, 22, 9))
    create_interaction!(@second_agent, Time.zone.local(2026, 7, 22, 15))

    report = AccountInteractionCostReport.new(account: @account).call

    assert_equal [ "2026-07-22", "2026-07-20" ], report[:days].pluck(:date)
    assert_equal [ "Research Assistant", "Second Cost Agent" ], report[:agents].pluck(:name)
    assert_equal "0.0045", report.dig(:days, 0, :total_amount_usd)
    assert_equal "0.00675", report[:total_amount_usd]
  end

  test "limits the displayed table to the latest thirty cost days" do
    31.times do |index|
      create_interaction!(@first_agent, Time.zone.local(2026, 7, 22, 12) - index.days)
    end

    report = AccountInteractionCostReport.new(account: @account).call

    assert_equal 30, report[:days].size
    assert_equal "2026-07-22", report.dig(:days, 0, :date)
    assert_equal "2026-06-23", report.dig(:days, 29, :date)
    assert_equal "0.06975", report[:total_amount_usd]
  end

  private

  def create_interaction!(agent, started_at)
    AgentRuntimeInteraction.create!(
      agent: agent,
      trigger_kind: "wake",
      started_at: started_at,
      telemetry_schema_version: 1,
      usage_scope: "trigger",
      usage_complete: true,
      provider: "anthropic",
      model: "claude-sonnet-5",
      uncached_input_tokens: 1_000,
      cache_creation_input_tokens: 0,
      cache_read_input_tokens: 0,
      output_tokens: 25
    )
  end

end
