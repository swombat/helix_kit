require "test_helper"

class BorrowContextToolTest < ActiveSupport::TestCase

  setup do
    @agent = agents(:research_assistant)
    @account = @agent.account

    # Current conversation
    @chat = @account.chats.new(
      title: "Current Chat",
      manual_responses: true,
      model_id: @agent.model_id
    )
    @chat.agent_ids = [ @agent.id ]
    @chat.save!

    # Source conversation (agent also participates)
    @source_chat = @account.chats.new(
      title: "Source Chat",
      manual_responses: true,
      model_id: @agent.model_id
    )
    @source_chat.agent_ids = [ @agent.id ]
    @source_chat.save!
  end

  test "returns error without agent context" do
    tool = BorrowContextTool.new(chat: @chat, current_agent: nil)

    result = tool.execute(conversation_id: @source_chat.obfuscated_id)

    assert result[:error]
    assert_includes result[:error], "context"
  end

  test "returns error without chat context" do
    tool = BorrowContextTool.new(chat: nil, current_agent: @agent)

    result = tool.execute(conversation_id: @source_chat.obfuscated_id)

    assert result[:error]
    assert_includes result[:error], "context"
  end

  test "returns error for non-participating conversation" do
    other_agent = agents(:code_reviewer)
    other_chat = @account.chats.new(
      title: "Other Chat",
      manual_responses: true,
      model_id: other_agent.model_id
    )
    other_chat.agent_ids = [ other_agent.id ]
    other_chat.save!

    tool = BorrowContextTool.new(chat: @chat, current_agent: @agent)

    result = tool.execute(conversation_id: other_chat.obfuscated_id)

    assert result[:error]
    assert_includes result[:error], "not found or you are not a participant"
  end

  test "returns error for current conversation" do
    tool = BorrowContextTool.new(chat: @chat, current_agent: @agent)

    result = tool.execute(conversation_id: @chat.obfuscated_id)

    assert result[:error]
    assert_includes result[:error], "Cannot borrow from the current conversation"
  end

  test "returns error for non-existent conversation ID" do
    tool = BorrowContextTool.new(chat: @chat, current_agent: @agent)

    result = tool.execute(conversation_id: "totallyBogusId")

    assert result[:error]
    assert_includes result[:error], "not found"
  end

  test "returns error for conversation with no messages" do
    tool = BorrowContextTool.new(chat: @chat, current_agent: @agent)

    result = tool.execute(conversation_id: @source_chat.obfuscated_id)

    assert result[:error]
    assert_includes result[:error], "No messages found"
  end

  test "stores minimal JSON on ChatAgent" do
    @source_chat.messages.create!(role: "user", content: "Hello from source")
    @source_chat.messages.create!(role: "assistant", agent: @agent, content: "Hello back")

    tool = BorrowContextTool.new(chat: @chat, current_agent: @agent)

    result = tool.execute(conversation_id: @source_chat.obfuscated_id)

    assert result[:success]
    assert_equal 2, result[:message_count]

    chat_agent = ChatAgent.find_by(chat: @chat, agent: @agent)
    json = chat_agent.borrowed_context_json

    assert_equal @source_chat.obfuscated_id, json["source_conversation_id"]
    assert_equal 2, json["messages"].length
  end

  test "formats messages with author and truncated content" do
    long_content = "x" * 3000
    @source_chat.messages.create!(role: "user", content: long_content)
    @source_chat.messages.create!(role: "assistant", agent: @agent, content: "Short response")

    tool = BorrowContextTool.new(chat: @chat, current_agent: @agent)

    tool.execute(conversation_id: @source_chat.obfuscated_id)

    chat_agent = ChatAgent.find_by(chat: @chat, agent: @agent)
    messages = chat_agent.borrowed_context_json["messages"]

    # Find the user message (no agent, falls back to "User")
    user_msg = messages.find { |m| m["author"] == "User" }
    assert user_msg, "Expected a message with author 'User'"
    assert user_msg["content"].length <= 2003 # 2000 + "..."

    # Find the agent message
    agent_msg = messages.find { |m| m["author"] == @agent.name }
    assert agent_msg, "Expected a message with author '#{@agent.name}'"
    assert_equal "Short response", agent_msg["content"]
  end

end
