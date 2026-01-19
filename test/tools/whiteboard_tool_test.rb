require "test_helper"

class WhiteboardToolTest < ActiveSupport::TestCase

  setup do
    @account = accounts(:personal_account)
    @agent = agents(:research_assistant)
    @chat = Chat.new(
      account: @account,
      title: "Test Chat",
      manual_responses: true,
      model_id_string: "openrouter/auto"
    )
    @chat.agents << @agent
    @chat.save!
    @tool = WhiteboardTool.new(chat: @chat, current_agent: @agent)
  end

  test "create returns board_created type" do
    result = @tool.execute(
      action: "create",
      name: "New Board",
      summary: "A test board",
      content: "Initial content"
    )

    assert_equal "board_created", result[:type]
    assert_not_nil result[:board_id]
    assert_equal "New Board", result[:name]
  end

  test "create without name returns param error with allowed_actions" do
    result = @tool.execute(action: "create", summary: "Test")

    assert_equal "error", result[:type]
    assert_match(/name required/, result[:error])
    assert_equal WhiteboardTool::ACTIONS, result[:allowed_actions]
  end

  test "create without summary returns param error with allowed_actions" do
    result = @tool.execute(action: "create", name: "Test")

    assert_equal "error", result[:type]
    assert_match(/summary required/, result[:error])
    assert_equal WhiteboardTool::ACTIONS, result[:allowed_actions]
  end

  test "update returns board_updated type" do
    board = whiteboards(:project_notes)
    result = @tool.execute(
      action: "update",
      board_id: board.obfuscated_id,
      content: "Updated content"
    )

    assert_equal "board_updated", result[:type]
    assert_equal board.revision + 1, result[:revision]
  end

  test "update with empty string clears content" do
    board = whiteboards(:project_notes)
    result = @tool.execute(
      action: "update",
      board_id: board.obfuscated_id,
      content: ""
    )

    assert_equal "board_updated", result[:type]
    assert_equal 0, result[:content_length]
    assert_equal "", board.reload.content
  end

  test "update fails for deleted board with error type" do
    board = whiteboards(:deleted_whiteboard)
    result = @tool.execute(
      action: "update",
      board_id: board.obfuscated_id,
      content: "New content"
    )

    assert_equal "error", result[:type]
    assert_match(/deleted/, result[:error])
    assert_equal WhiteboardTool::ACTIONS, result[:allowed_actions]
  end

  test "get returns board type with full details" do
    board = whiteboards(:project_notes)
    result = @tool.execute(action: "get", board_id: board.obfuscated_id)

    assert_equal "board", result[:type]
    assert_equal board.name, result[:name]
    assert_equal board.content, result[:content]
  end

  test "list returns board_list type with active boards only" do
    result = @tool.execute(action: "list")

    assert_equal "board_list", result[:type]
    names = result[:boards].map { |b| b[:name] }
    assert_includes names, "Project Notes"
    assert_not_includes names, "Archived Board"
  end

  test "delete returns board_deleted type" do
    board = whiteboards(:project_notes)
    result = @tool.execute(action: "delete", board_id: board.obfuscated_id)

    assert_equal "board_deleted", result[:type]
    assert board.reload.deleted?
  end

  test "delete already deleted board returns error" do
    board = whiteboards(:deleted_whiteboard)
    result = @tool.execute(action: "delete", board_id: board.obfuscated_id)

    assert_equal "error", result[:type]
    assert_match(/already deleted/, result[:error])
    assert_equal WhiteboardTool::ACTIONS, result[:allowed_actions]
  end

  test "restore returns board_restored type" do
    board = whiteboards(:deleted_whiteboard)
    board.update!(name: "Unique Restore Name")
    result = @tool.execute(action: "restore", board_id: board.obfuscated_id)

    assert_equal "board_restored", result[:type]
    assert_not board.reload.deleted?
  end

  test "restore fails if name conflicts" do
    deleted = whiteboards(:deleted_whiteboard)
    existing = whiteboards(:project_notes)

    # First delete the existing board so we can update the deleted one's name
    existing.soft_delete!
    # Now update the deleted board to have the same name as what project_notes had
    deleted.update!(name: "Project Notes")
    # Now restore project_notes so there's a conflict
    existing.restore!

    result = @tool.execute(action: "restore", board_id: deleted.obfuscated_id)

    assert_equal "error", result[:type]
    assert_match(/already in use/, result[:error])
    assert_equal WhiteboardTool::ACTIONS, result[:allowed_actions]
  end

  test "list_deleted returns deleted_board_list type" do
    result = @tool.execute(action: "list_deleted")

    assert_equal "deleted_board_list", result[:type]
    names = result[:boards].map { |b| b[:name] }
    assert_includes names, "Archived Board"
    assert_not_includes names, "Project Notes"
  end

  test "set_active returns active_board_set type" do
    board = whiteboards(:project_notes)
    result = @tool.execute(action: "set_active", board_id: board.obfuscated_id)

    assert_equal "active_board_set", result[:type]
    assert_equal board, @chat.reload.active_whiteboard
  end

  test "set_active with none returns active_board_cleared type" do
    board = whiteboards(:project_notes)
    @chat.update!(active_whiteboard: board)

    result = @tool.execute(action: "set_active", board_id: "none")

    assert_equal "active_board_cleared", result[:type]
    assert_nil @chat.reload.active_whiteboard
  end

  test "set_active with blank board_id clears active board" do
    board = whiteboards(:project_notes)
    @chat.update!(active_whiteboard: board)

    result = @tool.execute(action: "set_active", board_id: nil)

    assert_equal "active_board_cleared", result[:type]
    assert_nil @chat.reload.active_whiteboard
  end

  test "set_active fails for deleted board" do
    board = whiteboards(:deleted_whiteboard)
    result = @tool.execute(action: "set_active", board_id: board.obfuscated_id)

    assert_equal "error", result[:type]
    assert_match(/deleted/, result[:error])
    assert_equal WhiteboardTool::ACTIONS, result[:allowed_actions]
  end

  test "invalid action returns error with allowed_actions" do
    result = @tool.execute(action: "unknown")

    assert_equal "error", result[:type]
    assert_match(/Invalid action/, result[:error])
    assert_equal WhiteboardTool::ACTIONS, result[:allowed_actions]
  end

  test "requires agent context" do
    tool = WhiteboardTool.new(chat: @chat, current_agent: nil)
    result = tool.execute(action: "list")

    assert_equal "error", result[:type]
    assert_match(/context/, result[:error])
    assert_equal WhiteboardTool::ACTIONS, result[:allowed_actions]
  end

  test "board not found returns error with allowed_actions" do
    result = @tool.execute(action: "get", board_id: "nonexistent")

    assert_equal "error", result[:type]
    assert_match(/not found/, result[:error])
    assert_equal WhiteboardTool::ACTIONS, result[:allowed_actions]
  end

  # Tests for find_board name matching functionality
  test "find_board finds by exact obfuscated ID" do
    board = whiteboards(:project_notes)

    # Access the private find_board method for testing
    found_board = @tool.send(:find_board, board.obfuscated_id)

    assert_equal board, found_board
  end

  test "find_board finds by exact name when obfuscated ID lookup fails" do
    board = whiteboards(:project_notes)

    # Use exact name
    found_board = @tool.send(:find_board, "Project Notes")

    assert_equal board, found_board
  end

  test "find_board finds by case-insensitive name" do
    board = whiteboards(:project_notes)

    # Use different case
    found_board = @tool.send(:find_board, "project notes")

    assert_equal board, found_board
  end

  test "find_board finds by partial name with hyphen to wildcard conversion" do
    # Create a board with hyphens in the name
    board = @account.whiteboards.create!(
      name: "My-Special-Board",
      summary: "A board with hyphens"
    )

    # Search with partial match - hyphens become wildcards
    found_board = @tool.send(:find_board, "My-Special")

    assert_equal board, found_board
  end

  test "find_board returns nil for blank input" do
    found_board = @tool.send(:find_board, nil)
    assert_nil found_board

    found_board = @tool.send(:find_board, "")
    assert_nil found_board
  end

  test "find_board returns nil when no match found" do
    found_board = @tool.send(:find_board, "Nonexistent Board Name")
    assert_nil found_board
  end

  test "find_board prefers exact match over partial match" do
    # Create two boards - one exact match, one partial
    exact_board = @account.whiteboards.create!(
      name: "Test",
      summary: "Exact match board"
    )

    partial_board = @account.whiteboards.create!(
      name: "Test Board Extended",
      summary: "Partial match board"
    )

    # Should find the exact match
    found_board = @tool.send(:find_board, "Test")

    assert_equal exact_board, found_board
  end

  test "get action works with board name instead of ID" do
    board = whiteboards(:project_notes)

    # Use name instead of obfuscated ID
    result = @tool.execute(action: "get", board_id: "Project Notes")

    assert_equal "board", result[:type]
    assert_equal board.name, result[:name]
    assert_equal board.content, result[:content]
  end

  test "update action works with board name instead of ID" do
    board = whiteboards(:project_notes)

    # Use name instead of obfuscated ID
    result = @tool.execute(
      action: "update",
      board_id: "project notes", # case insensitive
      content: "Updated via name"
    )

    assert_equal "board_updated", result[:type]
    assert_equal "Updated via name", board.reload.content
  end

  test "delete action works with board name instead of ID" do
    board = @account.whiteboards.create!(
      name: "Board to Delete",
      summary: "Will be deleted by name"
    )

    # Delete using name
    result = @tool.execute(action: "delete", board_id: "Board to Delete")

    assert_equal "board_deleted", result[:type]
    assert board.reload.deleted?
  end

  test "set_active action works with board name instead of ID" do
    board = whiteboards(:project_notes)

    # Set active using name
    result = @tool.execute(action: "set_active", board_id: "Project Notes")

    assert_equal "active_board_set", result[:type]
    assert_equal board, @chat.reload.active_whiteboard
  end

end
