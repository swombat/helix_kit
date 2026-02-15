require "test_helper"

class FetchAudioToolTest < ActiveSupport::TestCase

  setup do
    @user = User.create!(
      email_address: "fetchaudio#{SecureRandom.hex(4)}@example.com",
      password: "password123"
    )
    @user.profile.update!(first_name: "Test", last_name: "User")
    @account = @user.personal_account
    @chat = Chat.create!(account: @account)
  end

  test "returns audio content for valid message with audio" do
    message = @chat.messages.create!(
      role: "user",
      user: @user,
      content: "Voice message",
      audio_source: true
    )
    message.audio_recording.attach(
      io: StringIO.new("fake audio data"),
      filename: "recording.webm",
      content_type: "audio/webm"
    )

    tool = FetchAudioTool.new(chat: @chat)
    result = tool.execute(message_id: message.obfuscated_id)

    assert result.is_a?(RubyLLM::Content)
  end

  test "returns error for message without audio" do
    message = @chat.messages.create!(
      role: "user",
      user: @user,
      content: "Text message"
    )

    tool = FetchAudioTool.new(chat: @chat)
    result = tool.execute(message_id: message.obfuscated_id)

    assert result.is_a?(Hash)
    assert_equal "This message has no audio recording", result[:error]
  end

  test "returns error for message not in chat" do
    other_chat = Chat.create!(account: @account)
    message = other_chat.messages.create!(
      role: "user",
      user: @user,
      content: "Other chat message",
      audio_source: true
    )
    message.audio_recording.attach(
      io: StringIO.new("fake audio data"),
      filename: "recording.webm",
      content_type: "audio/webm"
    )

    tool = FetchAudioTool.new(chat: @chat)
    result = tool.execute(message_id: message.obfuscated_id)

    assert result.is_a?(Hash)
    assert_equal "Message not found in this conversation", result[:error]
  end

  test "returns error for invalid message_id" do
    tool = FetchAudioTool.new(chat: @chat)
    result = tool.execute(message_id: "nonexistent-id")

    assert result.is_a?(Hash)
    assert_equal "Message not found in this conversation", result[:error]
  end

  test "returns error when no chat context" do
    tool = FetchAudioTool.new
    result = tool.execute(message_id: "some-id")

    assert result.is_a?(Hash)
    assert_equal "No chat context", result[:error]
  end

  test "scopes lookup to current chat" do
    # Create a message with audio in a different chat
    other_chat = Chat.create!(account: @account)
    other_message = other_chat.messages.create!(
      role: "user",
      user: @user,
      content: "Other chat voice",
      audio_source: true
    )
    other_message.audio_recording.attach(
      io: StringIO.new("fake audio data"),
      filename: "recording.webm",
      content_type: "audio/webm"
    )

    # Tool should not find it when scoped to @chat
    tool = FetchAudioTool.new(chat: @chat)
    result = tool.execute(message_id: other_message.obfuscated_id)

    assert result.is_a?(Hash)
    assert_equal "Message not found in this conversation", result[:error]
  end

end
