class CloseConversationTool < RubyLLM::Tool

  description "Close this conversation for yourself. You won't be prompted to continue it " \
              "during initiation cycles. Other agents and humans can still interact. " \
              "Use when a conversation has naturally concluded."

  def initialize(chat: nil, current_agent: nil)
    super()
    @chat = chat
    @current_agent = current_agent
  end

  def execute
    return error("Requires chat and agent context") unless @current_agent && @chat

    chat_agent = ChatAgent.find_by(chat: @chat, agent: @current_agent)
    return error("Not a member of this conversation") unless chat_agent

    chat_agent.close_for_initiation!
    { success: true, message: "Conversation closed for initiation." }
  end

  private

  def error(msg) = { error: msg }

end
