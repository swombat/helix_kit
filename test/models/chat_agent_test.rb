require "test_helper"

class ChatAgentTest < ActiveSupport::TestCase

  setup do
    @agent = agents(:research_assistant)
    @account = @agent.account
    @user = users(:user_1)
    @chat = @account.chats.new(
      title: "Test Chat",
      manual_responses: true,
      model_id: @agent.model_id
    )
    @chat.agent_ids = [ @agent.id ]
    @chat.save!
    @chat_agent = @chat.chat_agents.find_by(agent: @agent)
  end

  test "close_for_initiation! sets timestamp" do
    assert_nil @chat_agent.closed_for_initiation_at

    @chat_agent.close_for_initiation!

    assert @chat_agent.closed_for_initiation_at.present?
  end

  test "closed_for_initiation? returns true when closed" do
    @chat_agent.close_for_initiation!

    assert @chat_agent.closed_for_initiation?
  end

  test "closed_for_initiation? returns false when open" do
    refute @chat_agent.closed_for_initiation?
  end

  test "reopen_for_initiation! clears timestamp" do
    @chat_agent.close_for_initiation!
    assert @chat_agent.closed_for_initiation?

    @chat_agent.reopen_for_initiation!

    refute @chat_agent.closed_for_initiation?
    assert_nil @chat_agent.closed_for_initiation_at
  end

  test "closed_for_initiation scope returns closed records" do
    @chat_agent.close_for_initiation!

    assert_includes ChatAgent.closed_for_initiation, @chat_agent
  end

  test "open_for_initiation scope excludes closed records" do
    @chat_agent.close_for_initiation!

    assert_not_includes ChatAgent.open_for_initiation, @chat_agent
  end

  test "open_for_initiation scope returns open records" do
    assert_includes ChatAgent.open_for_initiation, @chat_agent
  end

end
