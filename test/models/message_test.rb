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

  # Hallucinated tool call detection tests

  test "has_json_prefix? detects JSON-prefixed assistant messages" do
    msg = Message.new(role: "assistant", content: '{"success": true}Hello')
    assert msg.has_json_prefix?
  end

  test "has_json_prefix? detects JSON with leading whitespace" do
    msg = Message.new(role: "assistant", content: '  {"success": true}Hello')
    assert msg.has_json_prefix?
  end

  test "has_json_prefix? returns false for user messages" do
    msg = Message.new(role: "user", content: '{"data": 1}Text')
    assert_not msg.has_json_prefix?
  end

  test "has_json_prefix? returns false for normal text" do
    msg = Message.new(role: "assistant", content: "Hello world")
    assert_not msg.has_json_prefix?
  end

  test "has_json_prefix? returns false for nil content" do
    msg = Message.new(role: "assistant", content: nil)
    assert_not msg.has_json_prefix?
  end

  test "has_json_prefix? returns false for empty content" do
    msg = Message.new(role: "assistant", content: "")
    assert_not msg.has_json_prefix?
  end

  test "fixable returns false when no agent present" do
    msg = Message.new(role: "assistant", content: '{"x": 1}Text', agent: nil)
    assert_not msg.fixable
  end

  test "fixable returns false for user messages" do
    agent = agents(:with_save_memory_tool)
    msg = Message.new(role: "user", content: '{"x": 1}Text', agent: agent)
    assert_not msg.fixable
  end

  test "fixable returns true for JSON-prefixed assistant message with agent" do
    agent = agents(:with_save_memory_tool)
    msg = Message.new(role: "assistant", content: '{"x": 1}Text', agent: agent)
    assert msg.fixable
  end

  test "as_json includes fixable attribute" do
    agent = agents(:with_save_memory_tool)
    message = @chat.messages.create!(
      role: "assistant",
      content: '{"memory_type": "journal", "content": "test"}Real text',
      agent: agent
    )

    json = message.as_json
    assert json["fixable"]
  end

  # fix_hallucinated_tool_calls! tests

  test "fix_hallucinated_tool_calls! raises for non-assistant message" do
    msg = @chat.messages.create!(
      role: "user",
      user: @user,
      content: '{"test": 1}Hello'
    )

    assert_raises RuntimeError do
      msg.fix_hallucinated_tool_calls!
    end
  end

  test "fix_hallucinated_tool_calls! raises when no JSON prefix" do
    msg = @chat.messages.create!(
      role: "assistant",
      content: "Normal text"
    )

    assert_raises RuntimeError do
      msg.fix_hallucinated_tool_calls!
    end
  end

  test "fix_hallucinated_tool_calls! raises when no agent present" do
    msg = @chat.messages.create!(
      role: "assistant",
      content: '{"test": 1}Hello',
      agent: nil
    )

    assert_raises RuntimeError do
      msg.fix_hallucinated_tool_calls!
    end
  end

  test "fix_hallucinated_tool_calls! strips JSON and executes tool" do
    agent = agents(:with_save_memory_tool)
    chat = Chat.create!(account: @account)

    # Add the agent to the chat so it has a chat association
    chat.agents << agent

    msg = chat.messages.create!(
      role: "assistant",
      agent: agent,
      content: '{"memory_type": "journal", "content": "Test memory"}You saw through me.'
    )

    assert_difference -> { agent.memories.count }, 1 do
      assert_difference -> { chat.messages.count }, 1 do  # Tool result message
        msg.fix_hallucinated_tool_calls!
      end
    end

    msg.reload
    assert_equal "You saw through me.", msg.content
    assert agent.memories.exists?(memory_type: "journal", content: "Test memory")
  end

  test "fix_hallucinated_tool_calls! handles JSON with nested braces" do
    agent = agents(:with_save_memory_tool)
    chat = Chat.create!(account: @account)
    chat.agents << agent

    msg = chat.messages.create!(
      role: "assistant",
      agent: agent,
      content: '{"memory_type": "journal", "content": "User said {something}"}Real text'
    )

    msg.fix_hallucinated_tool_calls!

    assert_equal "Real text", msg.reload.content
    assert agent.memories.exists?(content: "User said {something}")
  end

  test "fix_hallucinated_tool_calls! handles multiple JSON blocks" do
    agent = agents(:with_save_memory_tool)
    chat = Chat.create!(account: @account)
    chat.agents << agent

    msg = chat.messages.create!(
      role: "assistant",
      agent: agent,
      content: '{"memory_type": "journal", "content": "First"}{"memory_type": "core", "content": "Second"}Final'
    )

    assert_difference -> { agent.memories.count }, 2 do
      msg.fix_hallucinated_tool_calls!
    end

    assert_equal "Final", msg.reload.content
    assert agent.memories.exists?(memory_type: "journal", content: "First")
    assert agent.memories.exists?(memory_type: "core", content: "Second")
  end

  test "fix_hallucinated_tool_calls! records error for unknown tool structure" do
    agent = agents(:with_save_memory_tool)
    chat = Chat.create!(account: @account)
    chat.agents << agent

    msg = chat.messages.create!(
      role: "assistant",
      agent: agent,
      content: '{"unknown_field": "value"}Real text'
    )

    msg.fix_hallucinated_tool_calls!

    assert_equal "Real text", msg.reload.content
    error_msg = chat.messages.where("content LIKE ?", "Tool call failed:%").first
    assert error_msg, "Should have created an error message"
    assert_includes error_msg.content, "Could not identify tool"
  end

  test "fix_hallucinated_tool_calls! records error when tool not enabled" do
    agent = agents(:without_tools)  # Agent with no enabled tools
    chat = Chat.create!(account: @account)
    chat.agents << agent

    msg = chat.messages.create!(
      role: "assistant",
      agent: agent,
      content: '{"memory_type": "journal", "content": "Test"}Real text'
    )

    msg.fix_hallucinated_tool_calls!

    assert_equal "Real text", msg.reload.content
    error_msg = chat.messages.where("content LIKE ?", "Tool call failed:%").first
    assert error_msg, "Should have created an error message"
    assert_includes error_msg.content, "Could not identify tool"
  end

  test "fix_hallucinated_tool_calls! creates tool result message before original" do
    agent = agents(:with_save_memory_tool)
    chat = Chat.create!(account: @account)
    chat.agents << agent

    # Create a message at a specific time
    original_time = 10.seconds.ago
    msg = chat.messages.create!(
      role: "assistant",
      agent: agent,
      content: '{"memory_type": "journal", "content": "Test"}Real text',
      created_at: original_time
    )

    msg.fix_hallucinated_tool_calls!

    # Find the tool result message
    tool_msg = chat.messages.where.not(id: msg.id).first
    assert tool_msg.created_at < msg.reload.created_at, "Tool result message should be timestamped before the original"
    assert_equal [ "SaveMemoryTool" ], tool_msg.tools_used
  end

  test "fix_hallucinated_tool_calls! touches the chat" do
    agent = agents(:with_save_memory_tool)
    chat = Chat.create!(account: @account)
    chat.agents << agent

    msg = chat.messages.create!(
      role: "assistant",
      agent: agent,
      content: '{"memory_type": "journal", "content": "Test"}Real text'
    )

    chat_updated_at = chat.reload.updated_at

    # Small sleep to ensure time difference
    sleep 0.01
    msg.fix_hallucinated_tool_calls!

    assert chat.reload.updated_at > chat_updated_at, "Chat should have been touched"
  end

  # Timestamp hallucination tests

  test "has_timestamp_prefix? detects timestamp at start" do
    msg = Message.new(role: "assistant", content: "[2026-01-25 18:48] Hello world")
    assert msg.has_timestamp_prefix?
  end

  test "has_timestamp_prefix? returns false for text without timestamp" do
    msg = Message.new(role: "assistant", content: "Hello world")
    assert_not msg.has_timestamp_prefix?
  end

  test "has_timestamp_prefix? returns false for user messages" do
    msg = Message.new(role: "user", content: "[2026-01-25 18:48] Hello")
    assert_not msg.has_timestamp_prefix?
  end

  test "has_json_prefix? detects JSON after timestamp" do
    msg = Message.new(role: "assistant", content: '[2026-01-25 18:48] {"success": true}Hello')
    assert msg.has_json_prefix?
  end

  test "strip_leading_timestamp removes timestamp from start" do
    text = "[2026-01-25 18:48] Hello world"
    assert_equal "Hello world", Message.strip_leading_timestamp(text)
  end

  test "strip_leading_timestamp leaves text without timestamp unchanged" do
    text = "Hello world"
    assert_equal "Hello world", Message.strip_leading_timestamp(text)
  end

  test "strip_leading_timestamp handles nil" do
    assert_nil Message.strip_leading_timestamp(nil)
  end

  test "fixable returns true for timestamp-only message with agent" do
    agent = agents(:with_save_memory_tool)
    msg = Message.new(role: "assistant", content: "[2026-01-25 18:48] Hello", agent: agent)
    assert msg.fixable
  end

  test "fix_hallucinated_tool_calls! strips timestamp and JSON together" do
    agent = agents(:with_save_memory_tool)
    chat = Chat.create!(account: @account)
    chat.agents << agent

    msg = chat.messages.create!(
      role: "assistant",
      agent: agent,
      content: '[2026-01-25 18:48] {"memory_type": "journal", "content": "Test"}Real text'
    )

    msg.fix_hallucinated_tool_calls!

    assert_equal "Real text", msg.reload.content
    assert agent.memories.exists?(content: "Test")
  end

  # Tool result echo tests

  test "fix_hallucinated_tool_calls! silently strips tool result echoes with known type" do
    agent = agents(:with_save_memory_tool)
    chat = Chat.create!(account: @account)
    chat.agents << agent

    msg = chat.messages.create!(
      role: "assistant",
      agent: agent,
      content: '{"type": "github_commits", "commits": []}Real text'
    )

    assert_no_difference -> { chat.messages.count } do
      msg.fix_hallucinated_tool_calls!
    end

    assert_equal "Real text", msg.reload.content
  end

  test "fix_hallucinated_tool_calls! silently strips SaveMemoryTool success echo" do
    agent = agents(:with_save_memory_tool)
    chat = Chat.create!(account: @account)
    chat.agents << agent

    msg = chat.messages.create!(
      role: "assistant",
      agent: agent,
      content: '{"success": true, "memory_type": "journal", "content": "Stored"}Real text'
    )

    # Should NOT create any new messages (no error, no tool result)
    assert_no_difference -> { chat.messages.count } do
      msg.fix_hallucinated_tool_calls!
    end

    assert_equal "Real text", msg.reload.content
    # Should NOT create a new memory (it's a result echo, not a tool call)
    assert_not agent.memories.exists?(content: "Stored")
  end

  test "fix_hallucinated_tool_calls! strips multiple result echoes without errors" do
    agent = agents(:with_save_memory_tool)
    chat = Chat.create!(account: @account)
    chat.agents << agent

    msg = chat.messages.create!(
      role: "assistant",
      agent: agent,
      content: '{"type": "board_list", "boards": []}{"type": "search_results", "results": []}Real text'
    )

    assert_no_difference -> { chat.messages.count } do
      msg.fix_hallucinated_tool_calls!
    end

    assert_equal "Real text", msg.reload.content
  end

  test "fix_hallucinated_tool_calls! strips result echo but recovers real tool call" do
    agent = agents(:with_save_memory_tool)
    chat = Chat.create!(account: @account)
    chat.agents << agent

    msg = chat.messages.create!(
      role: "assistant",
      agent: agent,
      content: '{"type": "board_list", "boards": []}{"memory_type": "journal", "content": "Real call"}Final'
    )

    assert_difference -> { agent.memories.count }, 1 do
      msg.fix_hallucinated_tool_calls!
    end

    assert_equal "Final", msg.reload.content
    assert agent.memories.exists?(memory_type: "journal", content: "Real call")
  end

  test "fix_hallucinated_tool_calls! recognizes all known tool result types" do
    Message::TOOL_RESULT_TYPES.each do |type|
      agent = agents(:with_save_memory_tool)
      chat = Chat.create!(account: @account)
      chat.agents << agent

      msg = chat.messages.create!(
        role: "assistant",
        agent: agent,
        content: "{\"type\": \"#{type}\"}Text"
      )

      assert_no_difference -> { chat.messages.count }, "Type '#{type}' should be silently stripped" do
        msg.fix_hallucinated_tool_calls!
      end

      assert_equal "Text", msg.reload.content
    end
  end

  test "fix_hallucinated_tool_calls! strips timestamp-only message" do
    agent = agents(:with_save_memory_tool)
    chat = Chat.create!(account: @account)
    chat.agents << agent

    msg = chat.messages.create!(
      role: "assistant",
      agent: agent,
      content: "[2026-01-25 18:48] Hello world"
    )

    msg.fix_hallucinated_tool_calls!

    assert_equal "Hello world", msg.reload.content
  end

end
