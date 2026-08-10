require "test_helper"

module Api
  module V1
    class TelegramMediaControllerTest < ActionDispatch::IntegrationTest

      setup do
        @user = users(:confirmed_user)
        @agent = agents(:research_assistant)
        @api_key = ApiKey.generate_for(@user, name: "Resident Telegram media", agent: @agent)
        @subscription = @agent.telegram_subscriptions.create!(
          user: users(:user_1),
          telegram_chat_id: 333
        )
        @message = @subscription.telegram_messages.create!(
          role: "user",
          text: "[Photo]",
          media_kind: "photo",
          media_status: "ready",
          sent_at: Time.current
        )
        @message.media.attach(
          io: file_fixture("test_image.png").open,
          filename: "telegram-photo.png",
          content_type: "image/png"
        )
        @message.preview_frames.attach(
          io: file_fixture("test_image.png").open,
          filename: "telegram-frame.jpg",
          content_type: "image/jpeg"
        )
      end

      test "owning Resident can download original media" do
        get api_v1_telegram_conversation_message_media_url(@subscription, @message),
          headers: authorization

        assert_response :redirect
      end

      test "owning Resident can download a preview frame" do
        frame = @message.preview_frames_attachments.first

        get api_v1_telegram_conversation_message_preview_frame_url(@subscription, @message, frame),
          headers: authorization

        assert_response :redirect
      end

      test "another Resident cannot access the media" do
        other_agent = agents(:code_reviewer)
        other_key = ApiKey.generate_for(@user, name: "Other Resident Telegram media", agent: other_agent)

        get api_v1_telegram_conversation_message_media_url(@subscription, @message),
          headers: { "Authorization" => "Bearer #{other_key.raw_token}" }

        assert_response :not_found
      end

      test "user-scoped key cannot access Resident Telegram media" do
        user_key = ApiKey.generate_for(@user, name: "User Telegram media")

        get api_v1_telegram_conversation_message_media_url(@subscription, @message),
          headers: { "Authorization" => "Bearer #{user_key.raw_token}" }

        assert_response :forbidden
      end

      private

      def authorization
        { "Authorization" => "Bearer #{@api_key.raw_token}" }
      end

    end
  end
end
