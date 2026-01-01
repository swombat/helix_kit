require "test_helper"

class ChatWhiteboardTest < ActiveSupport::TestCase

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
  end

  test "whiteboard_index_context includes active boards" do
    context = @chat.send(:whiteboard_index_context)

    assert_includes context, "Project Notes"
    assert_includes context, "Meeting Notes"
    assert_not_includes context, "Archived Board"
  end

  test "whiteboard_index_context returns nil when no boards" do
    @chat.account.whiteboards.destroy_all

    assert_nil @chat.send(:whiteboard_index_context)
  end

  test "whiteboard_index_context marks over-limit boards" do
    board = whiteboards(:project_notes)
    board.update!(content: "x" * 11_000)

    context = @chat.send(:whiteboard_index_context)
    assert_includes context, "[OVER LIMIT"
  end

  test "active_whiteboard_context returns nil without active board" do
    assert_nil @chat.send(:active_whiteboard_context)
  end

  test "active_whiteboard_context includes board content" do
    board = whiteboards(:project_notes)
    @chat.update!(active_whiteboard: board)

    context = @chat.send(:active_whiteboard_context)
    assert_includes context, board.name
    assert_includes context, board.content
  end

  test "active_whiteboard_context returns nil for deleted active board" do
    board = whiteboards(:project_notes)
    @chat.update!(active_whiteboard: board)
    board.soft_delete!

    assert_nil @chat.send(:active_whiteboard_context)
  end

  test "system_message_for includes whiteboard contexts" do
    board = whiteboards(:project_notes)
    @chat.update!(active_whiteboard: board)

    message = @chat.send(:system_message_for, @agent)

    assert_includes message[:content], "Shared Whiteboards"
    assert_includes message[:content], "Active Whiteboard"
    assert_includes message[:content], board.content
  end

end
