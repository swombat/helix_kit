require "test_helper"
require "ostruct"

class ConversationInitiationJobTest < ActiveSupport::TestCase

  setup do
    @agent = agents(:research_assistant)
    @account = @agent.account
    @user = users(:user_1)

    # Create recent activity to make the account "active"
    @activity_log = AuditLog.create!(
      account: @account,
      action: "test_activity"
    )
  end

  # Helper to create a pending initiation
  def create_pending_initiation(agent)
    Chat.initiate_by_agent!(
      agent,
      topic: "Test Topic #{SecureRandom.hex(4)}",
      message: "Test message"
    )
  end

  # Helper to create a manual chat with agent
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

  # Helper to run job during daytime with mocked LLM
  def run_job_at_daytime_with_response(response_content, &block)
    response = OpenStruct.new(content: response_content)
    mock_chat = Object.new
    mock_chat.define_singleton_method(:ask) { |_prompt| response }

    # Set daytime (12:00 GMT is noon GMT which is within 9-20)
    daytime = Time.utc(2026, 1, 28, 12, 0, 0)

    travel_to daytime do
      RubyLLM.stub :chat, ->(**_opts) { mock_chat } do
        block.call if block
      end
    end
  end

  test "does not run outside daytime GMT hours (3am)" do
    nighttime = Time.utc(2026, 1, 28, 3, 0, 0) # 3am GMT

    travel_to nighttime do
      assert_no_changes -> { AuditLog.where(action: "agent_initiation_nothing").count } do
        ConversationInitiationJob.perform_now
      end
    end
  end

  test "does not run outside daytime GMT hours (21:00)" do
    nighttime = Time.utc(2026, 1, 28, 21, 0, 0) # 9pm GMT

    travel_to nighttime do
      assert_no_changes -> { AuditLog.where(action: "agent_initiation_nothing").count } do
        ConversationInitiationJob.perform_now
      end
    end
  end

  test "runs during daytime GMT hours and creates audit log" do
    # Use a class variable to track calls since define_singleton_method may have issues
    call_tracker = []

    daytime = Time.utc(2026, 1, 28, 12, 0, 0)

    travel_to daytime do
      job = ConversationInitiationJob.new

      # Verify daytime check
      assert job.send(:daytime?), "Expected to be daytime at 12:00 GMT"

      # Verify eligible agents exist
      eligible = job.send(:eligible_agents)
      assert eligible.exists?, "Expected eligible agents to exist. Got: #{eligible.count}"

      # Create a class to track calls
      mock_class = Class.new do
        define_method(:initialize) { |tracker| @tracker = tracker }
        define_method(:ask) do |_prompt|
          @tracker << Time.current
          OpenStruct.new(content: '{"action": "nothing", "reason": "No action needed"}')
        end
      end

      RubyLLM.stub :chat, ->(**_opts) { mock_class.new(call_tracker) } do
        ConversationInitiationJob.perform_now
      end
    end

    # Verify LLM was called
    assert_operator call_tracker.length, :>, 0, "Expected LLM to be called at least once. Calls: #{call_tracker.length}"

    # Should have created audit logs for processed agents
    assert AuditLog.exists?(action: "agent_initiation_nothing"),
           "Expected audit log to be created. Audit actions: #{AuditLog.pluck(:action).uniq}"
  end

  test "skips agents at hard cap" do
    Agent::INITIATION_CAP.times { create_pending_initiation(@agent) }

    daytime = Time.utc(2026, 1, 28, 12, 0, 0)
    travel_to daytime do
      ConversationInitiationJob.perform_now
    end

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

    initial_count = Chat.count

    run_job_at_daytime_with_response(response_json) do
      ConversationInitiationJob.perform_now
    end

    # Each active agent will create a chat, so we just verify at least one was created
    # and that our agent created the expected chat
    assert_operator Chat.count, :>, initial_count, "Expected at least one chat to be created"

    # Find the chat created by our specific agent
    chat = Chat.find_by(initiated_by_agent: @agent)
    assert_not_nil chat, "Expected chat to be created by #{@agent.name}"
    assert_equal "Weekly Update", chat.title
    assert_equal "It's time for the weekly check-in", chat.initiation_reason
    assert_equal "Hello team! Time for our weekly update.", chat.messages.first.content
  end

  test "continues conversation when agent decides to" do
    # Create a chat that the agent can continue
    chat = create_manual_chat_with_agent(@agent, title: "Existing Chat")
    chat.messages.create!(role: "user", user: @user, content: "Hello!")

    response_json = {
      action: "continue",
      conversation_id: chat.obfuscated_id,
      reason: "Want to follow up on the question"
    }.to_json

    run_job_at_daytime_with_response(response_json) do
      assert_enqueued_with(job: ManualAgentResponseJob, args: [ chat, @agent ]) do
        ConversationInitiationJob.perform_now
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

    run_job_at_daytime_with_response(response_json) do
      assert_no_difference -> { Chat.count } do
        ConversationInitiationJob.perform_now
      end
    end

    assert AuditLog.exists?(
      action: "agent_initiation_nothing",
      auditable: @agent,
      data: { "reason" => "No pressing matters to discuss" }
    )
  end

  test "handles malformed JSON response gracefully" do
    run_job_at_daytime_with_response("This is not valid JSON") do
      assert_no_difference -> { Chat.count } do
        ConversationInitiationJob.perform_now
      end
    end

    # Job now extracts JSON from prose, so message is more specific
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

    run_job_at_daytime_with_response(prose_response) do
      ConversationInitiationJob.perform_now
    end

    # Should successfully extract the JSON and use the reason from it
    assert AuditLog.exists?(
      action: "agent_initiation_nothing",
      data: { "reason" => "Waiting for human activity" }
    )
  end

  test "only processes agents from active accounts" do
    # Create an agent in an inactive account (no recent activity)
    inactive_account = accounts(:another_team)
    inactive_agent = inactive_account.agents.create!(
      name: "Inactive Agent",
      model_id: "openrouter/auto",
      active: true
    )

    # Remove any activity from inactive account
    AuditLog.where(account: inactive_account).delete_all
    Message.joins(:chat).where(chats: { account_id: inactive_account.id }).delete_all

    run_job_at_daytime_with_response('{"action": "nothing", "reason": "No action"}') do
      ConversationInitiationJob.perform_now
    end

    # Should have audit for active account's agent but not inactive account's agent
    assert AuditLog.exists?(auditable: @agent, action: "agent_initiation_nothing")
    refute AuditLog.exists?(auditable: inactive_agent, action: "agent_initiation_nothing")
  end

  test "continues processing other agents if one fails" do
    agent2 = agents(:code_reviewer)
    counter = { count: 0 }

    mock_chat_class = Class.new do
      define_method(:initialize) do |counter_ref|
        @counter_ref = counter_ref
      end

      define_method(:ask) do |_prompt|
        @counter_ref[:count] += 1
        raise "Simulated error" if @counter_ref[:count] == 1
        OpenStruct.new(content: '{"action": "nothing", "reason": "OK"}')
      end
    end

    daytime = Time.utc(2026, 1, 28, 12, 0, 0)
    travel_to daytime do
      RubyLLM.stub :chat, ->(**_opts) { mock_chat_class.new(counter) } do
        ConversationInitiationJob.perform_now
      end
    end

    # Should have attempted processing multiple agents
    assert_operator counter[:count], :>=, 2,
                    "Expected at least 2 LLM calls but got #{counter[:count]}"
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

    run_job_at_daytime_with_response(response_json) do
      assert_no_enqueued_jobs(only: ManualAgentResponseJob) do
        ConversationInitiationJob.perform_now
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

    run_job_at_daytime_with_response(response_json) do
      assert_no_enqueued_jobs(only: ManualAgentResponseJob) do
        ConversationInitiationJob.perform_now
      end
    end
  end

end
