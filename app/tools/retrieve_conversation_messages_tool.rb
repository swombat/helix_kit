class RetrieveConversationMessagesTool < RubyLLM::Tool

  DEFAULT_LIMIT = 5
  MAX_LIMIT = 10

  description "Retrieve verbatim original messages from the compacted portion of the current conversation. " \
              "Use this when the checkpoint summary is not detailed enough or when exact wording matters."

  param :message_id, type: :string,
        desc: "Optional exact message ID to retrieve"
  param :query, type: :string,
        desc: "Optional text to search for within compacted original messages"
  param :before_message_id, type: :string,
        desc: "Optional pagination cursor; return messages older than this message ID"
  param :limit, type: :integer,
        desc: "Number of messages to return (default 5, maximum 10)"

  def initialize(chat: nil, current_agent: nil)
    super()
    @chat = chat
    @current_agent = current_agent
  end

  def available?
    @chat&.checkpoint_summary.present? && @chat&.last_consolidated_message_id.present? &&
      @current_agent.present? && @chat.agents.exists?(@current_agent.id)
  end

  def execute(message_id: nil, query: nil, before_message_id: nil, limit: DEFAULT_LIMIT)
    return error("Requires a compacted conversation and participating agent context") unless available?

    if message_id.present?
      message = compacted_scope.find_by(id: Message.decode_id(message_id))
      return error("Compacted message not found") unless message

      return {
        success: true,
        messages: [ message_json(message) ],
        has_more: false,
        next_before_message_id: nil
      }
    end

    requested_limit = limit.to_i.clamp(1, MAX_LIMIT)
    scope = compacted_scope
    if before_message_id.present?
      decoded_cursor = Message.decode_id(before_message_id)
      return error("Invalid before_message_id") unless decoded_cursor

      scope = scope.where("messages.id < ?", decoded_cursor)
    end
    if query.present?
      safe_query = Message.sanitize_sql_like(query.to_s.first(500))
      scope = scope.where("messages.content ILIKE ?", "%#{safe_query}%")
    end

    page = scope.reorder(id: :desc).limit(requested_limit + 1).to_a
    has_more = page.length > requested_limit
    page = page.first(requested_limit)

    {
      success: true,
      messages: page.reverse.map { |message| message_json(message) },
      has_more: has_more,
      next_before_message_id: has_more ? page.last.to_param : nil
    }
  end

  private

  def compacted_scope
    @chat.messages
      .where(role: %w[user assistant])
      .where("messages.id <= ?", @chat.last_consolidated_message_id)
      .includes(:agent, :user)
  end

  def message_json(message)
    {
      id: message.to_param,
      author: message.agent&.name || message.user&.full_name ||
        message.user&.email_address&.split("@")&.first || "User",
      role: message.role,
      timestamp: message.created_at.iso8601,
      text: message.content.to_s
    }
  end

  def error(message)
    { error: message }
  end

end
