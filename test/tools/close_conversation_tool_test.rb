require "test_helper"

class CloseConversationToolTest < ActiveSupport::TestCase

  setup do
    @agent = agents(:research_assistant)
    @account = @agent.account
    @chat = @account.chats.new(
      title: "Test Chat",
      manual_responses: true,
      model_id: @agent.model_id
    )
    @chat.agent_ids = [ @agent.id ]
    @chat.save!
  end

  test "closes conversation for the agent" do
    tool = CloseConversationTool.new(chat: @chat, current_agent: @agent)

    result = tool.execute

    assert result[:success]
    assert @chat.chat_agents.find_by(agent: @agent).closed_for_initiation?
  end

  test "fails without current_agent" do
    tool = CloseConversationTool.new(chat: @chat, current_agent: nil)

    result = tool.execute

    assert result[:error]
    assert_includes result[:error], "chat and agent context"
  end

  test "fails without chat" do
    tool = CloseConversationTool.new(chat: nil, current_agent: @agent)

    result = tool.execute

    assert result[:error]
    assert_includes result[:error], "chat and agent context"
  end

  test "fails when agent is not a member of the chat" do
    other_agent = agents(:code_reviewer)
    tool = CloseConversationTool.new(chat: @chat, current_agent: other_agent)

    result = tool.execute

    assert result[:error]
    assert_includes result[:error], "Not a member"
  end

  test "is idempotent - closing twice succeeds" do
    tool = CloseConversationTool.new(chat: @chat, current_agent: @agent)

    tool.execute
    result = tool.execute

    assert result[:success]
  end

end
