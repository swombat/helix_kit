require "test_helper"
require "webmock/minitest"

class ExternalAgentTelegramRequestTest < ActiveSupport::TestCase

  setup do
    @agent = agents(:research_assistant)
    @agent.update!(
      runtime: "external",
      endpoint_url: "https://agent.example.com",
      trigger_bearer_token: "tr_valid",
      persistent_session: true
    )
    @subscription = @agent.telegram_subscriptions.create!(
      user: users(:user_1),
      telegram_chat_id: 111,
      telegram_username: "daniel_t"
    )
    @message = @subscription.telegram_messages.create!(
      role: "user",
      text: "Can you hear me?",
      sender_name: "Daniel",
      sender_username: "daniel_t",
      telegram_message_id: 9,
      sent_at: Time.current
    )
  end

  test "sends Telegram metadata and grounded transcript to the external trigger" do
    stub = stub_request(:post, "https://agent.example.com/trigger")
      .with do |request|
        body = JSON.parse(request.body)
        body["trigger_kind"] == "telegram" &&
          body["channel"] == "telegram" &&
          body["thread_id"] == @subscription.to_param &&
          body["history_cursor"] == @message.to_param &&
          body.dig("sender", "email") == users(:user_1).email_address &&
          body["text"] == "Can you hear me?" &&
          body["request"].include?("RECENT TELEGRAM TRANSCRIPT FROM DATABASE") &&
          body["request"].include?("Can you hear me?")
      end
      .to_return(status: 200, body: { status: "ok", chaos_session_id: "session-1" }.to_json)

    result = ExternalAgentTelegramRequest.new(
      agent: @agent,
      subscription: @subscription,
      telegram_message: @message
    ).call

    assert_equal 200, result[:status]
    assert_requested stub
    interaction = @agent.agent_runtime_interactions.last
    assert_equal "telegram", interaction.trigger_kind
    assert_equal @subscription.to_param, interaction.conversation_obfuscated_id
  end

  test "returns a busy response so the job can retry rapid follow-up messages" do
    stub_request(:post, "https://agent.example.com/trigger")
      .to_return(status: 409, body: { status: "already_running" }.to_json)

    result = ExternalAgentTelegramRequest.new(
      agent: @agent,
      subscription: @subscription,
      telegram_message: @message
    ).call

    assert_equal 409, result[:status]
  end

  test "Telegram full and delta requests include active house notices" do
    Notice.create!(
      scope: "account",
      account: @agent.account,
      notice_type: "announcement",
      body: "Telegram notice",
      expires_at: 1.day.from_now
    )
    request = ExternalAgentTelegramRequest.new(
      agent: @agent,
      subscription: @subscription,
      telegram_message: @message
    )

    assert_includes request.send(:request_text), "Telegram notice"
    assert_includes request.send(:request_delta_text), "Telegram notice"
    refute_includes request.send(:request_text), "Cross-room attention"
    refute_includes request.send(:request_delta_text), "Cross-room attention"
  end

  test "media prompt includes authenticated paths without Telegram or storage URLs" do
    @message.update!(
      media_kind: "photo",
      media_status: "ready",
      caption: "What is this?",
      text: "What is this?"
    )
    @message.media.attach(
      io: file_fixture("test_image.png").open,
      filename: "telegram-photo.png",
      content_type: "image/png"
    )
    request = ExternalAgentTelegramRequest.new(
      agent: @agent,
      subscription: @subscription,
      telegram_message: @message
    )

    prompt = request.send(:request_text)
    payload = request.send(:trigger_payload)

    assert_includes prompt, "Typed caption: What is this?"
    assert_includes prompt, "$HELIXKIT_BEARER_TOKEN"
    assert_includes prompt, "/api/v1/telegram_conversations/"
    assert_equal "photo", payload.dig(:media, :kind)
    refute_includes prompt, "api.telegram.org/file"
    refute_includes payload.to_json, "amazonaws.com"
    refute_includes payload.to_json, "123:ABC"
  end

end
