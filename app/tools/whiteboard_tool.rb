class WhiteboardTool < RubyLLM::Tool

  ACTIONS = %w[create update get list delete restore list_deleted set_active].freeze

  description "Manage shared whiteboards. Actions: #{ACTIONS.join(', ')}."

  param :action, type: :string,
        desc: "Action: #{ACTIONS.join(', ')}",
        required: true

  param :board_id, type: :string,
        desc: "Board ID (for: update, get, delete, restore, set_active)",
        required: false

  param :name, type: :string,
        desc: "Board name (required for create, optional for update)",
        required: false

  param :summary, type: :string,
        desc: "Board summary, max 250 chars (required for create, optional for update)",
        required: false

  param :content, type: :string,
        desc: "Markdown content. Update: omit to keep, empty string to clear.",
        required: false

  def initialize(chat: nil, current_agent: nil)
    super()
    @chat = chat
    @agent = current_agent
  end

  # Recovery interface for hallucinated tool calls
  def self.recoverable_from?(parsed_json)
    # Check for hallucinated whiteboard responses
    # Models output {type: "whiteboard", action: "update", board_id: "...", content: "..."}
    return true if parsed_json["type"] == "whiteboard" && parsed_json["action"].present?

    # Also check for action + board_id pattern (common hallucination format)
    parsed_json["action"].in?(ACTIONS) && parsed_json["board_id"].present?
  end

  def self.recover_from_hallucination(parsed_json, agent:, chat:)
    action = parsed_json["action"]
    return { error: "Missing action" } unless action.present?
    return { error: "Invalid action: #{action}" } unless ACTIONS.include?(action)

    # Build params from the hallucinated response
    params = {
      board_id: parsed_json["board_id"],
      name: parsed_json["name"],
      summary: parsed_json["summary"],
      content: parsed_json["content"]
    }.compact

    # Execute the tool
    tool = new(chat: chat, current_agent: agent)
    result = tool.execute(action: action, **params.symbolize_keys)

    if result[:type] == "error"
      { error: result[:error] }
    else
      { success: true, tool_name: name, result: result }
    end
  end

  def execute(action:, **params)
    return validation_error("Requires group conversation context") unless @agent && @chat
    return validation_error("Invalid action '#{action}'") unless ACTIONS.include?(action)

    send("#{action}_action", **params)
  end

  private

  def create_action(name: nil, summary: nil, content: nil, **)
    return param_error("create", "name") if name.blank?
    return param_error("create", "summary") if summary.blank?

    board = whiteboards.create!(
      name: name.strip, summary: summary.strip, content: content&.strip,
      last_edited_by: @agent, last_edited_at: Time.current
    )
    auto_link_to_chat(board)
    { type: "board_created", board_id: board.obfuscated_id, name: board.name,
      summary: board.summary, content_length: board.content.to_s.length }
  rescue ActiveRecord::RecordInvalid => e
    validation_error(e.record.errors.full_messages.join(", "))
  end

  def update_action(board_id: nil, name: nil, summary: nil, content: nil, **)
    board = find_board(board_id) or return validation_error("Board not found")
    return validation_error("Cannot update deleted board - restore first") if board.deleted?
    return validation_error("Provide name, summary, or content") if name.nil? && summary.nil? && content.nil?

    updates = { last_edited_by: @agent, last_edited_at: Time.current }
    updates[:name] = name.strip if name.present?
    updates[:summary] = summary.strip if summary.present?
    updates[:content] = content&.strip unless content.nil?
    board.update!(updates)
    auto_link_to_chat(board)

    result = { type: "board_updated", board_id: board.obfuscated_id, name: board.name,
               revision: board.revision, content_length: board.content.to_s.length }
    result[:warning] = "Exceeds #{Whiteboard::MAX_RECOMMENDED_LENGTH} chars" if board.over_recommended_length?
    result
  rescue ActiveRecord::RecordInvalid => e
    validation_error(e.record.errors.full_messages.join(", "))
  end

  def get_action(board_id: nil, **)
    board = find_board(board_id) or return validation_error("Board not found")
    auto_link_to_chat(board)
    { type: "board", board_id: board.obfuscated_id, name: board.name, summary: board.summary,
      content: board.content, revision: board.revision, content_length: board.content.to_s.length,
      last_edited_at: board.last_edited_at&.iso8601, last_edited_by: board.editor_name, deleted: board.deleted? }
  end

  def list_action(**)
    boards = whiteboards.active.by_name.map do |b|
      { id: b.obfuscated_id, name: b.name, summary: b.summary, length: b.content.to_s.length,
        revision: b.revision, over_limit: b.over_recommended_length? }
    end
    { type: "board_list", count: boards.size, boards: boards, active_board_id: @chat.active_whiteboard&.obfuscated_id }
  end

  def delete_action(board_id: nil, **)
    board = find_board(board_id) or return validation_error("Board not found")
    return validation_error("Board already deleted") if board.deleted?

    board.soft_delete!
    { type: "board_deleted", board_id: board.obfuscated_id, name: board.name }
  end

  def restore_action(board_id: nil, **)
    board = find_board(board_id) or return validation_error("Board not found")
    return validation_error("Board is not deleted") unless board.deleted?
    return validation_error("Name '#{board.name}' already in use") if whiteboards.active.exists?(name: board.name)

    board.restore!
    { type: "board_restored", board_id: board.obfuscated_id, name: board.name }
  end

  def list_deleted_action(**)
    boards = whiteboards.deleted.by_name.map do |b|
      { id: b.obfuscated_id, name: b.name, summary: b.summary, deleted_at: b.deleted_at.iso8601, length: b.content.to_s.length }
    end
    { type: "deleted_board_list", count: boards.size, boards: boards }
  end

  def set_active_action(board_id: nil, **)
    if board_id.blank? || board_id.to_s.downcase == "none"
      @chat.update!(active_whiteboard_id: nil)
      return { type: "active_board_cleared" }
    end

    board = find_board(board_id) or return validation_error("Board not found")
    return validation_error("Cannot set deleted board as active") if board.deleted?

    @chat.update!(active_whiteboard_id: board.id)
    { type: "active_board_set", board_id: board.obfuscated_id, name: board.name }
  end

  def auto_link_to_chat(board)
    return if @chat.active_whiteboard_id.present?
    return if board.deleted?

    @chat.update!(active_whiteboard_id: board.id)
  end

  def whiteboards = @chat.account.whiteboards

  def find_board(id_or_name)
    return nil if id_or_name.blank?

    # Try obfuscated ID first
    board = whiteboards.find_by_obfuscated_id(id_or_name)
    return board if board.present?

    # If not found by ID, try finding by name
    # First try exact match, then case-insensitive, then partial match
    whiteboards.find_by(name: id_or_name) ||
      whiteboards.where("LOWER(name) = LOWER(?)", id_or_name).first ||
      whiteboards.where("LOWER(name) LIKE LOWER(?)", "%#{id_or_name.gsub('-', '%')}%").first
  rescue Hashids::InputError
    # In rare cases where Hashids raises an error, fall back to name search
    whiteboards.find_by(name: id_or_name) ||
      whiteboards.where("LOWER(name) = LOWER(?)", id_or_name).first ||
      whiteboards.where("LOWER(name) LIKE LOWER(?)", "%#{id_or_name.gsub('-', '%')}%").first
  end

  def validation_error(msg) = { type: "error", error: msg, allowed_actions: ACTIONS }
  def param_error(action, param) = { type: "error", error: "#{param} required for #{action}", allowed_actions: ACTIONS }

end
