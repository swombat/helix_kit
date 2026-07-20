require "test_helper"
require "webmock/minitest"
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

  test "automatically exposes original-message retrieval after compaction" do
    @agent.update!(model_id: "openai/gpt-5-nano")
    @chat.update!(
      checkpoint_summary: "The earlier conversation was compacted.",
      last_consolidated_message_id: @user_message.id,
      last_consolidated_at: Time.current
    )

    request = stub_request(:post, "https://api.openai.com/v1/chat/completions")
      .with do |req|
        body = JSON.parse(req.body)
        body.fetch("tools", []).any? do |tool|
          tool.dig("function", "name") == "retrieve_conversation_messages"
        end
      end
      .to_return(
        status: 200,
        headers: { "Content-Type" => "application/json" },
        body: {
          id: "chatcmpl-retrieval-tool-test",
          object: "chat.completion",
          created: 1_784_220_000,
          model: "gpt-5-nano",
          choices: [
            {
              index: 0,
              message: { role: "assistant", content: "I can retrieve the originals when needed." },
              finish_reason: "stop"
            }
          ],
          usage: { prompt_tokens: 20, completion_tokens: 8, total_tokens: 28 }
        }.to_json
      )

    VCR.turned_off do
      ManualAgentResponseJob.perform_now(@chat, @agent)
    end

    assert_requested request
  end

  test "gpt 5.6 sol keeps tools by disabling reasoning effort on chat completions" do
    @agent.update!(
      model_id: "openai/gpt-5.6-sol",
      thinking_enabled: true,
      thinking_budget: 5000,
      prompt_cache_layout_v2: true,
      enabled_tools: [ "CloseConversationTool" ]
    )

    request = stub_request(:post, "https://api.openai.com/v1/chat/completions")
      .with do |req|
        body = JSON.parse(req.body)
        body["model"] == "gpt-5.6-sol" &&
          body["reasoning_effort"] == "none" &&
          body["tools"].present?
      end
      .to_return(
        status: 200,
        headers: { "Content-Type" => "application/json" },
        body: {
          id: "chatcmpl-sol-tool-test",
          object: "chat.completion",
          created: 1_784_220_000,
          model: "gpt-5.6-sol",
          choices: [
            {
              index: 0,
              message: { role: "assistant", content: "Sol tool response" },
              finish_reason: "stop"
            }
          ],
          usage: { prompt_tokens: 10, completion_tokens: 3, total_tokens: 13 }
        }.to_json
      )

    VCR.turned_off do
      ManualAgentResponseJob.perform_now(@chat, @agent)
    end

    assert_requested request
    response = @chat.messages.where(role: "assistant", agent: @agent).last
    assert_equal "Sol tool response", response.content
    assert_equal "provider_unsupported", response.reasoning_skip_reason
    assert_equal 2, response.prompt_layout_version
    assert_operator response.stable_prompt_bytes, :>, 0
    assert_operator response.transcript_prompt_bytes, :>, 0
    assert_operator response.envelope_prompt_bytes, :>, 0
    assert_match(/\A[0-9a-f]{64}\z/, response.stable_prompt_sha256)
  end

  test "external agent receives trigger request instead of local llm response" do
    @agent.update!(
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

    assert_no_difference "Message.count" do
      ManualAgentResponseJob.perform_now(@chat, @agent)
    end

    assert_requested trigger
  end

  test "offline external agent records unreachable message" do
    @agent.update!(
      runtime: "offline",
      uuid: SecureRandom.uuid_v7,
      endpoint_url: "https://agent.example.com",
      trigger_bearer_token: "tr_valid",
      health_state: "unhealthy",
      consecutive_health_failures: 6
    )

    assert_difference "Message.count", 1 do
      ManualAgentResponseJob.perform_now(@chat, @agent)
    end

    message = @chat.messages.order(:created_at).last
    assert_equal @agent, message.agent
    assert_includes message.content, "currently unreachable"
  end

end
