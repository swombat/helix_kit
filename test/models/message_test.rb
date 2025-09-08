require "test_helper"

class MessageTest < ActiveSupport::TestCase

  def setup
    @user = User.create!(
      email_address: "test#{SecureRandom.hex(4)}@example.com",
      password: "password123"
    )
    @user.profile.update!(first_name: "Test", last_name: "User")
    @account = @user.personal_account
    @chat = Chat.create!(account: @account)
  end

  test "belongs to chat with touch" do
    message = @chat.messages.create!(
      user: @user,
      role: "user",
      content: "Test message"
    )
    chat_updated_at = @chat.updated_at

    message.touch

    # Chat should have been touched too
    assert @chat.reload.updated_at > chat_updated_at
  end

  test "belongs to user optionally" do
    user_message = @chat.messages.create!(
      user: @user,
      role: "user",
      content: "User message"
    )
    ai_message = @chat.messages.create!(
      role: "assistant",
      content: "AI message"
    )

    assert_equal @user, user_message.user
    assert_nil ai_message.user
  end

  test "has many attached files" do
    message = @chat.messages.create!(
      user: @user,
      role: "user",
      content: "Test message"
    )
    assert message.respond_to?(:files)
  end

  test "validates role inclusion" do
    message = Message.new(
      chat: @chat,
      user: @user,
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
      chat: @chat,
      user: @user,
      role: "user"
    )

    message.content = ""
    assert_not message.valid?
    assert_includes message.errors[:content], "can't be blank"

    message.content = "Valid content"
    assert message.valid?
  end

  test "allows valid roles" do
    %w[user assistant system].each do |role|
      message = Message.create!(
        chat: @chat,
        user: (role == "user" ? @user : nil),
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
    message = @chat.messages.create!(
      user: @user,
      role: "user",
      content: "Test message"
    )
    # RubyLLM methods should be available - updated method name
    assert message.respond_to?(:to_llm)
  end

  test "broadcasts to chat" do
    assert_equal [ :chat ], Message.broadcast_targets
  end

end
