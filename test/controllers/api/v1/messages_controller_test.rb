require "test_helper"

module Api
  module V1
    class MessagesControllerTest < ActionDispatch::IntegrationTest

      setup do
        @user = users(:confirmed_user)
        @api_key = ApiKey.generate_for(@user, name: "Test")
        @token = @api_key.raw_token
        @account = @user.personal_account
        @chat = @account.chats.create!(model_id: "openrouter/auto", title: "Test Chat")
      end

      test "creates message and triggers AI" do
        @chat.messages.create!(content: "Hello", role: "user", user: @user)

        assert_enqueued_with(job: AiResponseJob) do
          post api_v1_conversation_messages_url(@chat),
               params: { content: "New message" },
               headers: { "Authorization" => "Bearer #{@token}" }
        end
        assert_response :created

        json = JSON.parse(response.body)
        assert json["message"]["id"].present?
        assert_equal "New message", json["message"]["content"]
        assert json["ai_response_triggered"]
      end

      test "rejects archived conversations" do
        @chat.archive!

        post api_v1_conversation_messages_url(@chat),
             params: { content: "New message" },
             headers: { "Authorization" => "Bearer #{@token}" }
        assert_response :unprocessable_entity

        json = JSON.parse(response.body)
        assert_equal "Conversation is archived or deleted", json["error"]
      end

      test "rejects discarded conversations" do
        @chat.discard!

        post api_v1_conversation_messages_url(@chat),
             params: { content: "New message" },
             headers: { "Authorization" => "Bearer #{@token}" }
        assert_response :unprocessable_entity
      end

      test "returns unauthorized without token" do
        post api_v1_conversation_messages_url(@chat),
             params: { content: "New message" }
        assert_response :unauthorized
      end

      test "returns 404 for other user's conversation" do
        other_user = users(:existing_user)
        other_account = other_user.personal_account
        other_chat = other_account.chats.create!(model_id: "openrouter/auto", title: "Other Chat")

        post api_v1_conversation_messages_url(other_chat),
             params: { content: "New message" },
             headers: { "Authorization" => "Bearer #{@token}" }
        assert_response :not_found
      end

    end
  end
end
