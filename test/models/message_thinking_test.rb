require "test_helper"

class MessageThinkingTest < ActiveSupport::TestCase

  setup do
    @user = User.create!(
      email_address: "thinking-test-#{SecureRandom.hex(4)}@example.com",
      password: "password123"
    )
    @user.profile.update!(first_name: "Test", last_name: "User")
    @account = @user.personal_account
    @chat = Chat.create!(account: @account)
    @message = @chat.messages.create!(
      role: "assistant",
      content: "Test response"
    )
  end

  test "thinking_preview returns nil when thinking is blank" do
    @message.thinking = nil
    assert_nil @message.thinking_preview

    @message.thinking = ""
    assert_nil @message.thinking_preview
  end

  test "thinking_preview returns short thinking content unchanged" do
    short_text = "This is a short thought."
    @message.thinking = short_text
    assert_equal short_text, @message.thinking_preview
  end

  test "thinking_preview truncates to 80 characters" do
    long_text = "a" * 100
    @message.thinking = long_text
    preview = @message.thinking_preview
    assert preview.length <= 80
    assert preview.end_with?("...")
  end

  test "thinking_preview truncates at word boundary" do
    @message.thinking = "This is a test of the thinking preview functionality that should be truncated at a word boundary not in the middle"
    preview = @message.thinking_preview

    # Should be truncated to ~80 chars
    assert preview.length <= 80
    assert preview.end_with?("...")

    # Should not split a word (no partial words before ...)
    # Extract text before the ...
    text_before_ellipsis = preview.sub(/\.\.\.$/, "").strip

    # Last character should be end of word (letter/number or punctuation, not space)
    refute text_before_ellipsis.end_with?(" "), "Should not end with space before ellipsis"
  end

  test "thinking_preview preserves complete words under limit" do
    @message.thinking = "First second third fourth fifth sixth seventh eighth ninth tenth eleventh"
    preview = @message.thinking_preview

    # Should preserve complete words
    words = preview.sub(/\.\.\.$/, "").strip.split(" ")
    words.each do |word|
      assert @message.thinking.include?(word), "Each word in preview should be complete"
    end
  end

  test "json_attributes includes thinking" do
    @message.thinking = "Some thinking content"
    json = @message.as_json
    assert json.key?("thinking")
    assert_equal "Some thinking content", json["thinking"]
  end

  test "json_attributes includes thinking_preview" do
    @message.thinking = "Some thinking content that is longer than eighty characters and should be truncated properly"
    json = @message.as_json
    assert json.key?("thinking_preview")
    assert json["thinking_preview"].length <= 80
    assert json["thinking_preview"].end_with?("...")
  end

  test "json_attributes includes nil thinking" do
    @message.thinking = nil
    json = @message.as_json
    assert json.key?("thinking")
    assert_nil json["thinking"]
    assert_nil json["thinking_preview"]
  end

  test "stream_thinking updates thinking column" do
    @message.thinking = ""
    @message.stream_thinking("First chunk")
    assert_equal "First chunk", @message.reload.thinking
  end

  test "stream_thinking appends to existing thinking" do
    @message.update_columns(thinking: "First chunk ")
    @message.stream_thinking("second chunk")
    assert_equal "First chunk second chunk", @message.reload.thinking
  end

  test "stream_thinking handles multiple chunks" do
    @message.update_columns(thinking: "")
    @message.stream_thinking("First ")
    @message.stream_thinking("second ")
    @message.stream_thinking("third")
    assert_equal "First second third", @message.reload.thinking
  end

  test "stream_thinking ignores empty chunks" do
    @message.update_columns(thinking: "Initial")
    @message.stream_thinking("")
    assert_equal "Initial", @message.reload.thinking
  end

  test "stream_thinking ignores nil chunks" do
    @message.update_columns(thinking: "Initial")
    @message.stream_thinking(nil)
    assert_equal "Initial", @message.reload.thinking
  end

  test "stream_thinking converts chunks to string" do
    @message.update_columns(thinking: "")
    @message.stream_thinking(123)
    assert_equal "123", @message.reload.thinking
  end

  test "stream_thinking handles thinking starting as nil" do
    @message.update_columns(thinking: nil)
    @message.stream_thinking("First chunk")
    assert_equal "First chunk", @message.reload.thinking
  end

  test "thinking can be set on message creation" do
    new_message = @chat.messages.create!(
      role: "assistant",
      content: "Response",
      thinking: "I need to think about this carefully"
    )
    assert_equal "I need to think about this carefully", new_message.thinking
  end

  test "thinking can be updated after creation" do
    @message.update!(thinking: "Updated thinking")
    assert_equal "Updated thinking", @message.reload.thinking
  end

  test "thinking persists across reload" do
    @message.update_columns(thinking: "Persisted thought")
    reloaded = Message.find(@message.id)
    assert_equal "Persisted thought", reloaded.thinking
  end

  test "long thinking content is stored without truncation" do
    long_thinking = "a" * 10000
    @message.update!(thinking: long_thinking)
    assert_equal long_thinking, @message.reload.thinking
  end

  test "thinking with special characters is preserved" do
    special_thinking = "Thinking with\nnewlines and\ttabs and \"quotes\" and 'apostrophes'"
    @message.update!(thinking: special_thinking)
    assert_equal special_thinking, @message.reload.thinking
  end

  test "thinking with unicode characters is preserved" do
    unicode_thinking = "Thinking with émojis 🤔 and spëcial çharacters"
    @message.update!(thinking: unicode_thinking)
    assert_equal unicode_thinking, @message.reload.thinking
  end

  test "message without thinking has nil thinking_preview" do
    @message.thinking = nil
    json = @message.as_json
    assert_nil json["thinking_preview"]
  end

  test "message with empty thinking has nil thinking_preview" do
    @message.thinking = ""
    json = @message.as_json
    assert_nil json["thinking_preview"]
  end

end
