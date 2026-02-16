class BorrowContextTool < RubyLLM::Tool

  description "Borrow recent messages from another conversation you participate in. " \
              "The messages will be included in your system context for your next response " \
              "in the current conversation. Use the conversation ID from your active conversations list."

  param :conversation_id, type: :string,
        desc: "The conversation ID to borrow context from (from your active conversations list)",
        required: true

  def initialize(chat: nil, current_agent: nil)
    super()
    @chat = chat
    @current_agent = current_agent
  end

  def execute(conversation_id:)
    return error("Requires chat and agent context") unless @current_agent && @chat

    source_chat = find_source_chat(conversation_id)
    return error("Conversation not found or you are not a participant") unless source_chat
    return error("Cannot borrow from the current conversation") if source_chat.id == @chat.id

    recent_messages = source_chat.messages
      .where(role: %w[user assistant])
      .order(created_at: :desc)
      .limit(10)
      .includes(:agent, :user)
      .reverse

    return error("No messages found in that conversation") if recent_messages.empty?

    formatted = recent_messages.map do |m|
      {
        "author" => m.agent&.name || m.user&.full_name || "User",
        "content" => m.content.to_s.truncate(2000)
      }
    end

    chat_agent = ChatAgent.find_by(chat: @chat, agent: @current_agent)
    chat_agent.update!(
      borrowed_context_json: {
        "source_conversation_id" => source_chat.obfuscated_id,
        "messages" => formatted
      }
    )

    {
      success: true,
      message: "Context from \"#{source_chat.title_or_default}\" will be included in your " \
               "system prompt for your next response in this conversation.",
      message_count: formatted.length
    }
  end

  private

  def find_source_chat(conversation_id)
    decoded_id = Chat.decode_id(conversation_id)
    return nil unless decoded_id

    ChatAgent.find_by(
      agent_id: @current_agent.id,
      chat_id: decoded_id
    )&.chat
  end

  def error(msg) = { error: msg }

end
