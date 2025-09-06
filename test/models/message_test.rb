require "test_helper"

class MessageTest < ActiveSupport::TestCase

  test "belongs to chat with touch" do
    message = messages(:user_message)
    chat_updated_at = message.chat.updated_at

    message.touch

    # Chat should have been touched too
    assert message.chat.reload.updated_at > chat_updated_at
  end

  test "belongs to user optionally" do
    user_message = messages(:user_message)
    ai_message = messages(:ai_message)

    assert_equal users(:user_1), user_message.user
    assert_nil ai_message.user
  end

  test "has many attached files" do
    message = messages(:user_message)
    assert message.respond_to?(:files)
  end

  test "validates role inclusion" do
    message = Message.new(
      chat: chats(:conversation),
      user: users(:user_1),
      content: "Test content"
    )

    message.role = "invalid"
    assert_not message.valid?
    assert_includes message.errors[:role], "is not included in the list"

    message.role = "user"
    assert message.valid?
  end

  test "validates content presence" do
    message = Message.new(
      chat: chats(:conversation),
      user: users(:user_1),
      role: "user"
    )

    message.content = ""
    assert_not message.valid?
    assert_includes message.errors[:content], "can't be blank"

    message.content = "Valid content"
    assert message.valid?
  end

  test "allows valid roles" do
    chat = chats(:conversation)
    user = users(:user_1)

    %w[user assistant system].each do |role|
      message = Message.create!(
        chat: chat,
        user: (role == "user" ? user : nil),
        role: role,
        content: "Test #{role} message"
      )
      assert message.persisted?
    end
  end

  test "includes required concerns" do
    assert Message.included_modules.include?(Broadcastable)
    assert Message.included_modules.include?(ObfuscatesId)
  end

  test "acts as message" do
    message = messages(:user_message)
    # RubyLLM methods should be available
    assert message.respond_to?(:to_openai)
  end

  test "broadcasts to chat" do
    message = messages(:user_message)
    assert_equal [ :chat ], message.class.broadcast_targets
  end

end
