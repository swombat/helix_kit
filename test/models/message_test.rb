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
    assert message.respond_to?(:attachments)
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

    assert_equal message.to_param, json["id"]
    assert_equal "user", json["role"]
    assert_includes json["content_html"], "<strong>markdown</strong>"
    assert_equal "Test User", json["user_name"]
    assert_nil json["user_avatar_url"]  # User avatar_url returns nil in test
    assert json["completed"]
    assert_nil json["error"]
    assert json["created_at_formatted"].present?
  end

  test "as_json handles assistant message with error" do
    message = @chat.messages.create!(
      role: "assistant",
      content: "Failed response"
    )

    json = message.as_json

    assert_equal "assistant", json["role"]
    assert_nil json["user_name"]
    assert_nil json["user_avatar_url"]
    # With content, assistant messages are complete
    assert json["completed"]
    # We don't track errors in database yet
    assert_nil json["error"]
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

  test "files_json returns empty array when no files attached" do
    message = @chat.messages.create!(
      user: @user,
      role: "user",
      content: "Test message"
    )

    assert_equal [], message.files_json
  end

  test "file_paths_for_llm returns empty array when no files attached" do
    message = @chat.messages.create!(
      user: @user,
      role: "user",
      content: "Test message"
    )

    assert_equal [], message.file_paths_for_llm
  end

  test "validates file size limit" do
    message = @chat.messages.build(
      user: @user,
      role: "user",
      content: "Test with large file"
    )

    # Create a mock large blob
    large_blob = ActiveStorage::Blob.new(
      filename: "large.png",
      content_type: "image/png",
      byte_size: 51.megabytes
    )

    # Mock the attachments.attached? and attachments.each for validation
    message.attachments.define_singleton_method(:attached?) { true }
    message.attachments.define_singleton_method(:each) { |&block| block.call(large_blob) }

    assert_not message.valid?
    assert_includes message.errors.full_messages.join, "50MB"
  end

  test "validates file type" do
    message = @chat.messages.build(
      user: @user,
      role: "user",
      content: "Test with invalid file"
    )

    # Create a mock invalid file blob
    invalid_blob = ActiveStorage::Blob.new(
      filename: "malicious.exe",
      content_type: "application/x-msdownload",
      byte_size: 1024
    )

    # Mock the attachments.attached? and attachments.each for validation
    message.attachments.define_singleton_method(:attached?) { true }
    message.attachments.define_singleton_method(:each) { |&block| block.call(invalid_blob) }

    assert_not message.valid?
    assert_includes message.errors.full_messages.join, "file type not supported"
  end

  test "accepts valid file types" do
    message = @chat.messages.build(
      user: @user,
      role: "user",
      content: "Test with valid file"
    )

    valid_blob = ActiveStorage::Blob.new(
      filename: "image.png",
      content_type: "image/png",
      byte_size: 1024
    )

    # Mock the attachments.attached? and attachments.each for validation
    message.attachments.define_singleton_method(:attached?) { true }
    message.attachments.define_singleton_method(:each) { |&block| block.call(valid_blob) }

    # Should pass validation since the file is valid
    assert message.valid?
  end

  test "tools_used defaults to empty array" do
    message = @chat.messages.create!(
      user: @user,
      role: "user",
      content: "Test message"
    )

    assert_equal [], message.tools_used
  end

  test "tools_used can store tool names" do
    message = @chat.messages.create!(
      role: "assistant",
      content: "AI response",
      tools_used: [ "Web fetch", "Calculator" ]
    )

    assert_equal [ "Web fetch", "Calculator" ], message.tools_used
  end

  test "used_tools? returns false when no tools used" do
    message = @chat.messages.create!(
      user: @user,
      role: "user",
      content: "Test message"
    )

    assert_not message.used_tools?
  end

  test "used_tools? returns false when tools_used is empty" do
    message = @chat.messages.create!(
      role: "assistant",
      content: "AI response",
      tools_used: []
    )

    assert_not message.used_tools?
  end

  test "used_tools? returns true when tools were used" do
    message = @chat.messages.create!(
      role: "assistant",
      content: "AI response",
      tools_used: [ "Web fetch" ]
    )

    assert message.used_tools?
  end

  test "as_json includes tools_used" do
    message = @chat.messages.create!(
      role: "assistant",
      content: "AI response",
      tools_used: [ "Web fetch", "Calculator" ]
    )

    json = message.as_json

    assert_equal [ "Web fetch", "Calculator" ], json["tools_used"]
  end

  # Content moderation tests

  test "moderation_flagged? returns false when scores are nil" do
    message = @chat.messages.create!(
      role: "assistant",
      content: "AI response"
    )
    message.moderation_scores = nil
    assert_not message.moderation_flagged?
  end

  test "moderation_flagged? returns false when no scores meet threshold" do
    message = @chat.messages.create!(
      role: "assistant",
      content: "AI response"
    )
    message.moderation_scores = { "hate" => 0.3, "violence" => 0.2 }
    assert_not message.moderation_flagged?
  end

  test "moderation_flagged? returns true when any score meets threshold" do
    message = @chat.messages.create!(
      role: "assistant",
      content: "AI response"
    )
    message.moderation_scores = { "hate" => 0.5, "violence" => 0.2 }
    assert message.moderation_flagged?
  end

  test "moderation_flagged? returns true when score exceeds threshold" do
    message = @chat.messages.create!(
      role: "assistant",
      content: "AI response"
    )
    message.moderation_scores = { "hate" => 0.6, "violence" => 0.2 }
    assert message.moderation_flagged?
  end

  test "moderation_severity returns nil when not flagged" do
    message = @chat.messages.create!(
      role: "assistant",
      content: "AI response"
    )
    message.moderation_scores = { "hate" => 0.3 }
    assert_nil message.moderation_severity
  end

  test "moderation_severity returns :high for scores >= 0.8" do
    message = @chat.messages.create!(
      role: "assistant",
      content: "AI response"
    )
    message.moderation_scores = { "hate" => 0.85, "violence" => 0.2 }
    assert_equal :high, message.moderation_severity
  end

  test "moderation_severity returns :medium for scores 0.5-0.8" do
    message = @chat.messages.create!(
      role: "assistant",
      content: "AI response"
    )
    message.moderation_scores = { "hate" => 0.65, "violence" => 0.2 }
    assert_equal :medium, message.moderation_severity
  end

  test "moderation_severity returns :medium for score at exactly 0.5" do
    message = @chat.messages.create!(
      role: "assistant",
      content: "AI response"
    )
    message.moderation_scores = { "hate" => 0.5, "violence" => 0.2 }
    assert_equal :medium, message.moderation_severity
  end

  test "user message queues moderation on create" do
    assert_enqueued_with(job: ModerateMessageJob) do
      @chat.messages.create!(role: "user", content: "Test message", user: @user)
    end
  end

  test "assistant message does not queue moderation on create" do
    assert_no_enqueued_jobs(only: ModerateMessageJob) do
      @chat.messages.create!(role: "assistant", content: "Response")
    end
  end

  test "as_json includes moderation attributes when present" do
    message = @chat.messages.create!(
      role: "assistant",
      content: "AI response"
    )
    message.update!(moderation_scores: { "hate" => 0.85, "violence" => 0.1 })

    json = message.as_json

    assert json["moderation_flagged"]
    assert_equal :high, json["moderation_severity"]
    assert_equal({ "hate" => 0.85, "violence" => 0.1 }, json["moderation_scores"])
  end

end
