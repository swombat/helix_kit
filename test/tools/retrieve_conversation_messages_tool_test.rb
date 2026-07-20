require "test_helper"

class RetrieveConversationMessagesToolTest < ActiveSupport::TestCase

  setup do
    @agent = agents(:research_assistant)
    @user = users(:user_1)
    @chat = @agent.account.chats.new(
      title: "Compacted chat",
      manual_responses: true,
      model_id: @agent.model_id
    )
    @chat.agent_ids = [ @agent.id ]
    @chat.save!

    @older = @chat.messages.create!(role: "user", content: "The exact launch phrase is blue heron.", user: @user)
    @boundary = @chat.messages.create!(role: "assistant", content: "I will remember that.", agent: @agent)
    @recent = @chat.messages.create!(role: "user", content: "This remains in the active transcript.", user: @user)
    @chat.update!(
      checkpoint_summary: "A launch phrase was agreed.",
      last_consolidated_message_id: @boundary.id,
      last_consolidated_at: Time.current
    )
    @tool = RetrieveConversationMessagesTool.new(chat: @chat, current_agent: @agent)
  end

  test "is available only for a participating agent in a compacted conversation" do
    assert @tool.available?
    refute RetrieveConversationMessagesTool.new(chat: @chat, current_agent: agents(:code_reviewer)).available?
    refute RetrieveConversationMessagesTool.new(chat: nil, current_agent: @agent).available?
  end

  test "retrieves exact compacted message text by id" do
    result = @tool.execute(message_id: @older.to_param)

    assert result[:success]
    assert_equal "The exact launch phrase is blue heron.", result.dig(:messages, 0, :text)
    assert_equal @older.to_param, result.dig(:messages, 0, :id)
  end

  test "searches only the compacted portion" do
    compacted = @tool.execute(query: "blue heron")
    recent = @tool.execute(query: "active transcript")

    assert_equal [ @older.to_param ], compacted[:messages].map { |message| message[:id] }
    assert_empty recent[:messages]
  end

  test "paginates compacted messages with an obfuscated cursor" do
    result = @tool.execute(limit: 1)

    assert_equal 1, result[:messages].length
    assert result[:has_more]
    assert_predicate result[:next_before_message_id], :present?

    next_page = @tool.execute(limit: 1, before_message_id: result[:next_before_message_id])
    assert_equal 1, next_page[:messages].length
    refute_equal result.dig(:messages, 0, :id), next_page.dig(:messages, 0, :id)
  end

  test "rejects an invalid pagination cursor" do
    result = @tool.execute(before_message_id: "not-a-message")

    assert_equal "Invalid before_message_id", result[:error]
  end

end
