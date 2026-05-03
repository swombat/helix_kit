require "test_helper"

class AgentInitiationDecisionJobTest < ActiveSupport::TestCase

  setup do
    @agent = agents(:research_assistant)
    @agent.update!(model_id: "openai/gpt-5-nano")
    @account = @agent.account
    @user = users(:user_1)
    @job = AgentInitiationDecisionJob.new
  end

  test "records a nothing decision through RubyLLM" do
    @agent.update!(
      system_prompt: <<~PROMPT
        For this self-initiation decision test, respond with JSON only:
        {"action":"nothing","reason":"No pressing matters to discuss"}
      PROMPT
    )

    travel_to Time.zone.local(2026, 5, 3, 12, 0, 0) do
      VCR.use_cassette("jobs/agent_initiation_decision_job/nothing_decision") do
        assert_no_difference -> { Chat.count } do
          AgentInitiationDecisionJob.perform_now(@agent)
        end
      end
    end

    log = AuditLog.find_by(
      action: "agent_initiation_nothing",
      auditable: @agent
    )
    assert_not_nil log
    assert_predicate log.data["reason"], :present?
  end

  test "blocks initiation when agent at hard cap" do
    Agent::INITIATION_CAP.times { create_pending_initiation(@agent) }

    assert_no_difference -> { Chat.initiated.where(initiated_by_agent: @agent).count } do
      execute_decision(action: "initiate", topic: "New Topic", message: "Hello!", reason: "Want to start something")
    end
  end

  test "allows continuation when agent at hard cap" do
    Agent::INITIATION_CAP.times { create_pending_initiation(@agent) }
    chat = create_manual_chat_with_agent(@agent, title: "Existing Chat")
    chat.messages.create!(role: "user", user: @user, content: "Hello!")

    assert_enqueued_with(job: ManualAgentResponseJob, args: [ chat, @agent, { initiation_reason: "Following up" } ]) do
      execute_decision(action: "continue", conversation_id: chat.obfuscated_id, reason: "Following up")
    end
  end

  test "initiates conversation when agent decides to" do
    execute_decision(
      action: "initiate",
      topic: "Weekly Update",
      message: "Hello team! Time for our weekly update.",
      reason: "It's time for the weekly check-in"
    )

    chat = Chat.find_by(initiated_by_agent: @agent)
    assert_not_nil chat
    assert_equal "Weekly Update", chat.title
    assert_equal "It's time for the weekly check-in", chat.initiation_reason
    assert_equal "Hello team! Time for our weekly update.", chat.messages.first.content
  end

  test "continues conversation when agent decides to" do
    chat = create_manual_chat_with_agent(@agent, title: "Existing Chat")
    chat.messages.create!(role: "user", user: @user, content: "Hello!")

    assert_enqueued_with(job: ManualAgentResponseJob, args: [ chat, @agent, { initiation_reason: "Want to follow up" } ]) do
      execute_decision(action: "continue", conversation_id: chat.obfuscated_id, reason: "Want to follow up")
    end
  end

  test "parses malformed response as a safe nothing decision" do
    decision = @job.send(:parse_decision_response, "This is not valid JSON")

    assert_equal "nothing", decision[:action]
    assert_equal "Could not extract decision from response", decision[:reason]
    assert_equal "This is not valid JSON", decision[:raw_response]
  end

  test "extracts JSON from prose-wrapped responses" do
    decision = @job.send(:parse_decision_response, <<~TEXT)
      After considering the current state, here is my decision:
      {"action": "nothing", "reason": "Waiting for human activity"}
      I hope this helps!
    TEXT

    assert_equal "nothing", decision[:action]
    assert_equal "Waiting for human activity", decision[:reason]
  end

  test "does not continue archived chat" do
    chat = create_manual_chat_with_agent(@agent, title: "Archived Chat")
    chat.messages.create!(role: "user", user: @user, content: "Hello!")
    chat.archive!

    assert_no_enqueued_jobs(only: ManualAgentResponseJob) do
      execute_decision(action: "continue", conversation_id: chat.obfuscated_id, reason: "Following up")
    end
  end

  test "does not continue discarded chat" do
    chat = create_manual_chat_with_agent(@agent, title: "Discarded Chat")
    chat.messages.create!(role: "user", user: @user, content: "Hello!")
    chat.discard!

    assert_no_enqueued_jobs(only: ManualAgentResponseJob) do
      execute_decision(action: "continue", conversation_id: chat.obfuscated_id, reason: "Following up")
    end
  end

  test "blocks agent-only initiation when at agent-only cap" do
    Agent::AGENT_ONLY_INITIATION_CAP.times do |i|
      Chat.initiate_by_agent!(
        @agent,
        topic: "#{Chat::AGENT_ONLY_PREFIX} Topic #{i}",
        message: "Test message"
      )
    end

    assert_no_difference -> { Chat.initiated.where(initiated_by_agent: @agent).count } do
      execute_decision(action: "initiate", topic: "Agent Discussion", message: "Hey!", agent_only: true, reason: "Want to chat")
    end
  end

  test "allows human initiation when only at agent-only cap" do
    Agent::AGENT_ONLY_INITIATION_CAP.times do |i|
      Chat.initiate_by_agent!(
        @agent,
        topic: "#{Chat::AGENT_ONLY_PREFIX} Topic #{i}",
        message: "Test message"
      )
    end

    execute_decision(action: "initiate", topic: "Human Discussion", message: "Hey!", reason: "Want to discuss with humans")

    chat = Chat.where(initiated_by_agent: @agent).not_agent_only.last
    assert_not_nil chat
    assert_equal "Human Discussion", chat.title
  end

  test "allows agent-only initiation when only at human cap" do
    Agent::INITIATION_CAP.times { create_pending_initiation(@agent) }

    execute_decision(action: "initiate", topic: "Agent Discussion", message: "Hey agents!", agent_only: true, reason: "Want to chat")

    chat = Chat.where(initiated_by_agent: @agent).agent_only.last
    assert_not_nil chat
    assert chat.title.start_with?(Chat::AGENT_ONLY_PREFIX)
  end

  test "nighttime initiation checks agent-only cap not human cap" do
    Agent::AGENT_ONLY_INITIATION_CAP.times do |i|
      Chat.initiate_by_agent!(
        @agent,
        topic: "#{Chat::AGENT_ONLY_PREFIX} Topic #{i}",
        message: "Test message"
      )
    end

    @job.instance_variable_set(:@nighttime, true)

    assert_no_difference -> { Chat.initiated.where(initiated_by_agent: @agent).count } do
      execute_decision(action: "initiate", topic: "Night Discussion", message: "Hello!", reason: "Nighttime chat")
    end
  end

  test "agent_only flag prefixes topic with AGENT_ONLY_PREFIX" do
    execute_decision(action: "initiate", topic: "Agent Chat", message: "Hey!", agent_only: true, reason: "Private discussion")

    chat = Chat.where(initiated_by_agent: @agent).agent_only.last
    assert_not_nil chat
    assert_equal "#{Chat::AGENT_ONLY_PREFIX} Agent Chat", chat.title
  end

  private

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

  def execute_decision(decision)
    @job.send(:execute_decision, @agent, decision.symbolize_keys)
  end

end
