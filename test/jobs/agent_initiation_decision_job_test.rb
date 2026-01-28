require "test_helper"
require "ostruct"

class AgentInitiationDecisionJobTest < ActiveSupport::TestCase

  setup do
    @agent = agents(:research_assistant)
    @account = @agent.account
    @user = users(:user_1)
  end

  def create_pending_initiation(agent)
    Chat.initiate_by_agent!(
      agent,
      topic: "Test Topic #{SecureRandom.hex(4)}",
      message: "Test message"
    )
  end

  def create_manual_chat_with_agent(agent, title: "Test Chat")
    chat = @account.chats.new(
      title: title,
      manual_responses: true,
      model_id: agent.model_id
    )
    chat.agent_ids = [ agent.id ]
    chat.save!
    chat
  end

  def run_with_response(response_content, &block)
    response = OpenStruct.new(content: response_content)
    mock_chat = Object.new
    mock_chat.define_singleton_method(:ask) { |_prompt| response }

    RubyLLM.stub :chat, ->(**_opts) { mock_chat } do
      block.call if block
    end
  end

  test "skips agent at hard cap" do
    Agent::INITIATION_CAP.times { create_pending_initiation(@agent) }

    AgentInitiationDecisionJob.perform_now(@agent)

    assert AuditLog.exists?(
      action: "agent_initiation_skipped",
      auditable: @agent,
      data: { "reason" => "at_hard_cap" }
    )
  end

  test "initiates conversation when agent decides to" do
    response_json = {
      action: "initiate",
      topic: "Weekly Update",
      message: "Hello team! Time for our weekly update.",
      reason: "It's time for the weekly check-in"
    }.to_json

    run_with_response(response_json) do
      AgentInitiationDecisionJob.perform_now(@agent)
    end

    chat = Chat.find_by(initiated_by_agent: @agent)
    assert_not_nil chat
    assert_equal "Weekly Update", chat.title
    assert_equal "It's time for the weekly check-in", chat.initiation_reason
    assert_equal "Hello team! Time for our weekly update.", chat.messages.first.content
  end

  test "continues conversation when agent decides to" do
    chat = create_manual_chat_with_agent(@agent, title: "Existing Chat")
    chat.messages.create!(role: "user", user: @user, content: "Hello!")

    response_json = {
      action: "continue",
      conversation_id: chat.obfuscated_id,
      reason: "Want to follow up on the question"
    }.to_json

    run_with_response(response_json) do
      assert_enqueued_with(job: ManualAgentResponseJob, args: [ chat, @agent, { initiation_reason: "Want to follow up on the question" } ]) do
        AgentInitiationDecisionJob.perform_now(@agent)
      end
    end

    assert AuditLog.exists?(
      action: "agent_initiation_continue",
      auditable: @agent,
      data: { "conversation_id" => chat.obfuscated_id, "reason" => "Want to follow up on the question" }
    )
  end

  test "does nothing when agent decides to do nothing" do
    response_json = {
      action: "nothing",
      reason: "No pressing matters to discuss"
    }.to_json

    run_with_response(response_json) do
      assert_no_difference -> { Chat.count } do
        AgentInitiationDecisionJob.perform_now(@agent)
      end
    end

    assert AuditLog.exists?(
      action: "agent_initiation_nothing",
      auditable: @agent,
      data: { "reason" => "No pressing matters to discuss" }
    )
  end

  test "handles malformed JSON response gracefully" do
    run_with_response("This is not valid JSON") do
      assert_no_difference -> { Chat.count } do
        AgentInitiationDecisionJob.perform_now(@agent)
      end
    end

    assert AuditLog.exists?(
      action: "agent_initiation_nothing",
      data: { "reason" => "Could not extract decision from response" }
    )
  end

  test "extracts JSON from prose-wrapped responses" do
    prose_response = <<~TEXT
      After considering the current state, here is my decision:
      {"action": "nothing", "reason": "Waiting for human activity"}
      I hope this helps!
    TEXT

    run_with_response(prose_response) do
      AgentInitiationDecisionJob.perform_now(@agent)
    end

    assert AuditLog.exists?(
      action: "agent_initiation_nothing",
      data: { "reason" => "Waiting for human activity" }
    )
  end

  test "does not continue archived chat" do
    chat = create_manual_chat_with_agent(@agent, title: "Archived Chat")
    chat.messages.create!(role: "user", user: @user, content: "Hello!")
    chat.archive!

    response_json = {
      action: "continue",
      conversation_id: chat.obfuscated_id,
      reason: "Following up"
    }.to_json

    run_with_response(response_json) do
      assert_no_enqueued_jobs(only: ManualAgentResponseJob) do
        AgentInitiationDecisionJob.perform_now(@agent)
      end
    end
  end

  test "does not continue discarded chat" do
    chat = create_manual_chat_with_agent(@agent, title: "Discarded Chat")
    chat.messages.create!(role: "user", user: @user, content: "Hello!")
    chat.discard!

    response_json = {
      action: "continue",
      conversation_id: chat.obfuscated_id,
      reason: "Following up"
    }.to_json

    run_with_response(response_json) do
      assert_no_enqueued_jobs(only: ManualAgentResponseJob) do
        AgentInitiationDecisionJob.perform_now(@agent)
      end
    end
  end

  test "logs error and does not crash on LLM failure" do
    mock_chat = Object.new
    mock_chat.define_singleton_method(:ask) { |_prompt| raise "API timeout" }

    RubyLLM.stub :chat, ->(**_opts) { mock_chat } do
      assert_nothing_raised do
        AgentInitiationDecisionJob.perform_now(@agent)
      end
    end
  end

end
