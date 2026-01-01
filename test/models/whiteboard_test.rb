require "test_helper"

class WhiteboardTest < ActiveSupport::TestCase

  test "validates name presence" do
    board = Whiteboard.new(account: accounts(:personal_account))
    assert_not board.valid?
    assert_includes board.errors[:name], "can't be blank"
  end

  test "validates name uniqueness within account for active boards" do
    existing = whiteboards(:project_notes)
    board = Whiteboard.new(account: existing.account, name: existing.name)
    assert_not board.valid?
    assert_includes board.errors[:name], "has already been taken"
  end

  test "allows duplicate names for deleted boards" do
    existing = whiteboards(:project_notes)
    existing.soft_delete!
    board = Whiteboard.new(account: existing.account, name: existing.name, summary: "New")
    assert board.valid?
  end

  test "soft_delete sets deleted_at" do
    board = whiteboards(:project_notes)
    assert_nil board.deleted_at
    board.soft_delete!
    assert_not_nil board.deleted_at
  end

  test "soft_delete clears active board references" do
    board = whiteboards(:project_notes)
    account = accounts(:personal_account)
    agent = agents(:research_assistant)
    chat = Chat.new(
      account: account,
      title: "Test Chat",
      manual_responses: true,
      model_id_string: "openrouter/auto"
    )
    chat.agents << agent
    chat.save!
    chat.update!(active_whiteboard: board)

    board.soft_delete!
    chat.reload

    assert_nil chat.active_whiteboard_id
  end

  test "restore clears deleted_at" do
    board = whiteboards(:deleted_whiteboard)
    assert board.deleted?
    board.update!(name: "Unique Name For Restore")
    board.restore!
    assert_not board.deleted?
  end

  test "content change increments revision" do
    board = whiteboards(:project_notes)
    original = board.revision

    board.update!(content: "New content")

    assert_equal original + 1, board.revision
  end

  test "over_recommended_length? returns true for long content" do
    board = whiteboards(:project_notes)
    board.update!(content: "x" * 10_001)
    assert board.over_recommended_length?
  end

  test "over_recommended_length? returns false for short content" do
    board = whiteboards(:project_notes)
    assert_not board.over_recommended_length?
  end

  test "editor_name returns agent name" do
    board = whiteboards(:project_notes)
    board.update!(last_edited_by: agents(:research_assistant))
    assert_equal agents(:research_assistant).name, board.editor_name
  end

  test "editor_name returns user name or email prefix" do
    board = whiteboards(:meeting_notes)
    board.update!(last_edited_by: users(:user_1))
    user = users(:user_1)
    expected = user.full_name.presence || user.email_address.split("@").first
    assert_equal expected, board.editor_name
  end

  test "editor_name returns nil when no editor" do
    board = whiteboards(:deleted_whiteboard)
    assert_nil board.editor_name
  end

  test "deleted? returns true for deleted boards" do
    assert whiteboards(:deleted_whiteboard).deleted?
  end

  test "deleted? returns false for active boards" do
    assert_not whiteboards(:project_notes).deleted?
  end

end
