require "test_helper"

class TelegramMessageTest < ActiveSupport::TestCase

  setup do
    agent = agents(:research_assistant)
    subscription = agent.telegram_subscriptions.create!(
      user: users(:user_1),
      telegram_chat_id: 987_654
    )
    @message = subscription.telegram_messages.create!(
      role: "user",
      text: "[Voice message — processing]",
      media_kind: "voice",
      media_status: "pending",
      sent_at: Time.current
    )
  end

  test "validates media kind and status" do
    @message.media_kind = "sticker"
    assert_not @message.valid?
    assert_includes @message.errors[:media_kind], "is not included in the list"

    @message.media_kind = "voice"
    @message.media_status = "lost"
    assert_not @message.valid?
    assert_includes @message.errors[:media_status], "is not included in the list"
  end

  test "rebuilds voice text with caption and machine transcription" do
    @message.update!(
      caption: "My note",
      transcription: "This is the spoken part.",
      media_status: "ready"
    )

    assert_equal "My note\n\nTranscription: This is the spoken part.", @message.normalized_text
  end

  test "uses an honest placeholder for silent successful transcription" do
    @message.update!(transcription: nil, media_status: "ready")

    assert_equal "[Voice message]", @message.normalized_text
    assert_nil @message.media_metadata["transcription_status"]
  end

  test "omits media JSON for text messages" do
    @message.update!(media_kind: nil, media_status: nil, text: "Plain text")

    assert_not @message.transcript_json.key?(:media)
  end

  test "includes only authenticated application paths for attachments" do
    @message.update!(media_status: "ready")
    @message.media.attach(
      io: file_fixture("test_audio.webm").open,
      filename: "voice.webm",
      content_type: "audio/webm"
    )

    media = @message.media_json
    assert_match %r{\A/api/v1/telegram_conversations/}, media.dig(:original, :download_path)
    refute_includes media.to_json, "api.telegram.org"
    refute_includes media.to_json, "amazonaws.com"
  end

end
