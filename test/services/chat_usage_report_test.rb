require "test_helper"

class ChatUsageReportTest < ActiveSupport::TestCase

  setup do
    @agent = agents(:research_assistant)
    @chat = @agent.account.chats.create!(
      model_id: "openai/gpt-5.4",
      title: "Usage report",
      manual_responses: true,
      agent_ids: [ @agent.id ]
    )
  end

  test "groups message and runtime token categories by model" do
    @chat.messages.create!(
      role: "assistant",
      agent: @agent,
      content: "Inline response",
      model_id_string: "openai/gpt-5.4",
      input_tokens: 100,
      cache_creation_tokens: 20,
      cached_tokens: 30,
      output_tokens: 40,
      thinking_tokens: 10
    )
    AgentRuntimeInteraction.create!(
      agent: @agent,
      chat: @chat,
      trigger_kind: "conversation",
      started_at: Time.current,
      telemetry_schema_version: 1,
      chaos_telemetry_status: "detailed",
      usage_scope: "invocation",
      usage_complete: true,
      provider: "anthropic",
      model: "claude-fable-5",
      uncached_input_tokens: 200,
      cache_creation_input_tokens: 50,
      cache_read_input_tokens: 500,
      output_tokens: 60,
      reasoning_output_tokens: 15
    )

    report = ChatUsageReport.new(chat: @chat).call

    assert_equal 2, report[:models].size
    assert report[:instrumentation_complete]
    assert_equal 300, report.dig(:totals, :uncached_input_tokens)
    assert_equal 530, report.dig(:totals, :cache_read_input_tokens)
    assert_equal 100, report.dig(:totals, :output_tokens)
  end

  test "marks rows incomplete instead of treating missing categories as zero" do
    @chat.messages.create!(
      role: "assistant",
      agent: @agent,
      content: "Legacy response",
      model_id_string: "openai/gpt-5.4",
      input_tokens: 100,
      output_tokens: 40
    )

    report = ChatUsageReport.new(chat: @chat).call

    assert_not report[:instrumentation_complete]
    assert_equal 1, report[:incomplete_rows]
    assert_nil report.dig(:totals, :cache_read_input_tokens)
    assert_match(/Unknown values/, report[:instrumentation_note])
  end

  test "does not double count messages posted by externally hosted agents" do
    @agent.update!(runtime: "external")
    @chat.messages.create!(
      role: "assistant",
      agent: @agent,
      content: "Posted through the HelixKit API",
      model_id_string: "claude-fable-5",
      input_tokens: 200,
      output_tokens: 20
    )
    AgentRuntimeInteraction.create!(
      agent: @agent,
      chat: @chat,
      trigger_kind: "conversation",
      started_at: Time.current,
      telemetry_schema_version: 1,
      chaos_telemetry_status: "detailed",
      usage_scope: "trigger",
      usage_complete: true,
      provider: "anthropic",
      model: "claude-fable-5",
      uncached_input_tokens: 200,
      cache_creation_input_tokens: 0,
      cache_read_input_tokens: 0,
      output_tokens: 20,
      reasoning_output_tokens: 0
    )

    report = ChatUsageReport.new(chat: @chat).call

    assert_equal 1, report[:row_count]
    assert_equal 200, report.dig(:totals, :uncached_input_tokens)
    assert_equal 20, report.dig(:totals, :output_tokens)
  end

end
