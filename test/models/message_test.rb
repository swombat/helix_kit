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

  test "completed? returns true for user messages" do
    message = @chat.messages.create!(
      user: @user,
      role: "user",
      content: "Test message"
    )
    assert message.completed?
  end

  test "completed? returns true for completed assistant messages" do
    message = @chat.messages.create!(
      role: "assistant",
      content: "AI response"
    )
    assert message.completed?
  end

  test "completed? returns false for incomplete assistant messages" do
    # Build message without saving (since content validation would fail)
    message = @chat.messages.build(
      role: "assistant",
      content: ""
    )
    assert_not message.completed?
  end

  test "user_name returns user full name" do
    message = @chat.messages.create!(
      user: @user,
      role: "user",
      content: "Test message"
    )
    assert_equal "Test User", message.user_name
  end

  test "user_name returns nil when no user" do
    message = @chat.messages.create!(
      role: "assistant",
      content: "AI response"
    )
    assert_nil message.user_name
  end

  test "user_avatar_url returns user avatar" do
    message = @chat.messages.create!(
      user: @user,
      role: "user",
      content: "Test message"
    )
    # User avatar_url returns nil in test environment
    assert_nil message.user_avatar_url
  end

  test "created_at_formatted returns formatted time" do
    message = @chat.messages.create!(
      user: @user,
      role: "user",
      content: "Test message",
      created_at: Time.parse("2024-01-15 14:30:00 UTC")
    )
    formatted = message.created_at_formatted
    assert_includes formatted, ":30"
    assert_includes formatted, "M" # AM or PM
  end

  test "content_html renders markdown" do
    message = @chat.messages.create!(
      role: "assistant",
      content: "# Heading\n\nSome **bold** text and `code`"
    )

    html = message.content_html
    assert_includes html, "<h1>Heading</h1>"
    assert_includes html, "<strong>bold</strong>"
    assert_includes html, "<code>code</code>"
  end

  test "content_html handles nil content" do
    # Build message without saving (since content is required)
    message = @chat.messages.build(
      role: "assistant",
      content: nil
    )

    # Should not raise error
    html = message.content_html
    assert_equal "", html
  end

  test "content_html filters dangerous HTML" do
    message = @chat.messages.create!(
      role: "assistant",
      content: "<script>alert('xss')</script>Safe content"
    )

    html = message.content_html
    assert_not_includes html, "<script>"
    assert_includes html, "Safe content"
  end

  test "as_json returns complete message data" do
    message = @chat.messages.create!(
      user: @user,
      role: "user",
      content: "Test **markdown**"
    )

    json = message.as_json

    assert_equal message.to_param, json[:id]
    assert_equal "user", json[:role]
    assert_includes json[:content_html], "<strong>markdown</strong>"
    assert_equal "Test User", json[:user_name]
    assert_nil json[:user_avatar_url]  # User avatar_url returns nil in test
    assert json[:completed]
    assert_nil json[:error]
    assert json[:created_at_formatted].present?
  end

  test "as_json handles assistant message with error" do
    message = @chat.messages.create!(
      role: "assistant",
      content: "Failed response"
    )

    json = message.as_json

    assert_equal "assistant", json[:role]
    assert_nil json[:user_name]
    assert_nil json[:user_avatar_url]
    # With content, assistant messages are complete
    assert json[:completed]
    # We don't track errors in database yet
    assert_nil json[:error]
  end

  test "stream_content updates content and sets streaming" do
    message = @chat.messages.create!(
      role: "assistant",
      content: "Initial"
    )

    assert_not message.streaming?

    # Test that stream_content works
    message.stream_content(" chunk")

    message.reload
    assert_equal "Initial chunk", message.content
    assert message.streaming?
  end

  test "stream_content only sets streaming true once" do
    message = @chat.messages.create!(
      role: "assistant",
      content: "",
      streaming: true
    )

    # Should already be streaming
    assert message.streaming?

    message.stream_content(" more content")

    message.reload
    assert_equal " more content", message.content
    assert message.streaming?  # Should still be streaming
  end

  test "stop_streaming sets streaming to false" do
    message = @chat.messages.create!(
      role: "assistant",
      content: "Final content",
      streaming: true
    )

    assert message.streaming?

    message.stop_streaming

    message.reload
    assert_not message.streaming?
  end

  test "stop_streaming does nothing if not streaming" do
    message = @chat.messages.create!(
      role: "assistant",
      content: "Final content",
      streaming: false
    )

    # Should not be streaming
    assert_not message.streaming?

    message.stop_streaming

    message.reload
    assert_not message.streaming?  # Should still not be streaming
  end

end
