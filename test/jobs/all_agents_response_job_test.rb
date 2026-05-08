require "test_helper"
require "webmock/minitest"
class AllAgentsResponseJobTest < ActiveJob::TestCase

  setup do
    @user = users(:user_1)
    @account = accounts(:personal_account)
    @agent1 = agents(:research_assistant)
    @agent2 = agents(:code_reviewer)
    # Build the chat first, set agent_ids, then save to satisfy validation
    @chat = @account.chats.new(
      model_id: "openrouter/auto",
      title: "Test Group Chat",
      manual_responses: true
    )
    @chat.agent_ids = [ @agent1.id, @agent2.id ]
    @chat.save!
    @user_message = @chat.messages.create!(
      content: "Hello, agents!",
      role: "user",
      user: @user
    )
  end

  test "job is enqueued properly" do
    agent_ids = [ @agent1.id, @agent2.id ]
    assert_enqueued_with(job: AllAgentsResponseJob, args: [ @chat, agent_ids ]) do
      AllAgentsResponseJob.perform_later(@chat, agent_ids)
    end
  end

  test "processes first agent and queues remaining" do
    agent_ids = [ @agent1.id, @agent2.id ]
    @agent1.update!(model_id: "openai/gpt-5-nano", system_prompt: "Reply with one short sentence as the first test agent.")
    recorded_at = Time.zone.parse("2026-05-03 11:52 UTC")
    @user_message.update!(created_at: recorded_at)

    travel_to recorded_at do
      VCR.use_cassette("jobs/all_agents_response_job/processes_first_agent") do
        assert_enqueued_with(job: AllAgentsResponseJob, args: [ @chat, [ @agent2.id ] ]) do
          AllAgentsResponseJob.perform_now(@chat, agent_ids)
        end
      end
    end

    ai_message = @chat.messages.where(role: "assistant", agent: @agent1).last
    assert_not_nil ai_message, "First agent's message should be created"
    assert_predicate ai_message.content, :present?
  end

  test "does nothing when agent_ids is empty" do
    assert_no_enqueued_jobs do
      AllAgentsResponseJob.perform_now(@chat, [])
    end

    # No new messages should be created (only the original user message)
    assert_equal 1, @chat.messages.count
  end

  test "builds context messages for the selected agent" do
    context = @chat.build_context_for_agent(@agent1, thinking_enabled: false, provider: :openrouter)

    assert_equal 2, context.length, "Should include system prompt and user message"
    assert_equal "system", context.first[:role]
    assert_equal "user", context.second[:role]
  end

  test "sequential processing creates context for subsequent agents" do
    @chat.messages.create!(
      role: "assistant",
      agent: @agent1,
      content: "Response from agent 1"
    )

    second_agent_context = @chat.build_context_for_agent(@agent2, thinking_enabled: false, provider: :openrouter)

    # Second agent should see system + user message + first agent's response
    assert_equal 3, second_agent_context.length, "Second agent should see all prior messages"
    assert_equal "system", second_agent_context[0][:role]
    assert_equal "user", second_agent_context[1][:role]
    # The third message is from agent1, formatted as a user message with [AgentName] prefix
    assert_equal "user", second_agent_context[2][:role]
    assert_includes second_agent_context[2][:content], "Research Assistant"
  end

  test "queues remaining agents when an anthropic thinking agent is skipped for missing API key" do
    anthropic_agent = @account.agents.create!(
      name: "Claude",
      model_id: "anthropic/claude-opus-4.5",
      system_prompt: "You are Claude.",
      thinking_enabled: true,
      thinking_budget: 5000
    )

    @chat.agent_ids = [ anthropic_agent.id, @agent2.id ]
    @chat.save!

    original_anthropic_key = RubyLLM.config.anthropic_api_key
    RubyLLM.config.anthropic_api_key = "<missing>"

    begin
      assert_enqueued_with(job: AllAgentsResponseJob, args: [ @chat, [ @agent2.id ] ]) do
        AllAgentsResponseJob.perform_now(@chat, [ anthropic_agent.id, @agent2.id ])
      end
    ensure
      RubyLLM.config.anthropic_api_key = original_anthropic_key
    end

    skipped_message = @chat.messages.where(role: "assistant", agent: anthropic_agent).last
    assert_not_nil skipped_message
    assert_equal "anthropic_key_unavailable", skipped_message.reasoning_skip_reason
  end

  test "external first agent receives trigger and remaining agents are queued" do
    @agent1.update!(
      runtime: "external",
      uuid: SecureRandom.uuid_v7,
      endpoint_url: "https://agent.example.com",
      trigger_bearer_token: "tr_valid",
      health_state: "healthy",
      consecutive_health_failures: 0
    )
    trigger = stub_request(:post, "https://agent.example.com/trigger")
      .with(headers: { "Authorization" => "Bearer tr_valid" })
      .to_return(status: 200, body: { status: "accepted" }.to_json)

    assert_enqueued_with(job: AllAgentsResponseJob, args: [ @chat, [ @agent2.id ] ]) do
      assert_no_difference "Message.count" do
        AllAgentsResponseJob.perform_now(@chat, [ @agent1.id, @agent2.id ])
      end
    end

    assert_requested trigger
  end

end
