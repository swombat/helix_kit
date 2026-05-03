require "test_helper"
class ManualAgentResponseJobTest < ActiveJob::TestCase

  setup do
    @user = users(:user_1)
    @account = accounts(:personal_account)
    @agent = agents(:research_assistant)
    # Build the chat first, set agent_ids, then save to satisfy validation
    @chat = @account.chats.new(
      model_id: "openrouter/auto",
      title: "Test Group Chat",
      manual_responses: true
    )
    @chat.agent_ids = [ @agent.id ]
    @chat.save!
    @user_message = @chat.messages.create!(
      content: "Hello, agents!",
      role: "user",
      user: @user
    )
  end

  test "job is enqueued properly" do
    assert_enqueued_with(job: ManualAgentResponseJob, args: [ @chat, @agent ]) do
      ManualAgentResponseJob.perform_later(@chat, @agent)
    end
  end

  test "creates message attributed to agent through RubyLLM" do
    @agent.update!(model_id: "openai/gpt-5-nano")
    @agent.update!(system_prompt: "Reply with one short sentence as a research assistant.")
    recorded_at = Time.zone.parse("2026-05-03 11:51 UTC")
    @user_message.update!(created_at: recorded_at)

    travel_to recorded_at do
      VCR.use_cassette("jobs/manual_agent_response_job/creates_agent_message") do
        ManualAgentResponseJob.perform_now(@chat, @agent)
      end
    end

    ai_message = @chat.messages.where(role: "assistant").last
    assert_not_nil ai_message, "AI message should be created"
    assert_equal @agent, ai_message.agent
    assert_predicate ai_message.content, :present?
    assert_not ai_message.streaming?
  end

  test "builds context for agent response" do
    context = @chat.build_context_for_agent(@agent, thinking_enabled: false, provider: :openrouter)

    assert_equal 2, context.length, "Should include system prompt and user message"
    assert_equal "system", context.first[:role]
    assert_equal "user", context.second[:role]
    assert_includes context.second[:content], "Hello, agents!"
  end

end
