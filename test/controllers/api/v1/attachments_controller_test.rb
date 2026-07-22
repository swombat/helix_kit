require "test_helper"

module Api
  module V1
    class AttachmentsControllerTest < ActionDispatch::IntegrationTest

      setup do
        @user = users(:confirmed_user)
        @agent = agents(:research_assistant)
        @api_key = ApiKey.generate_for(@user, name: "Hosted agent attachment access", agent: @agent)
        @token = @api_key.raw_token
        @chat = @agent.account.chats.create!(model_id: "openrouter/auto", title: "Attachment access")
        @chat.agents << @agent
        @message = @chat.messages.create!(content: "Please inspect this file", role: "user", user: @user)
        @message.attachments.attach(
          io: file_fixture("test_document.pdf").open,
          filename: "test_document.pdf",
          content_type: "application/pdf"
        )
        @attachment = @message.attachments_attachments.first
      end

      test "redirects participating agent to a storage download URL" do
        get api_v1_conversation_message_attachment_url(@chat, @message, @attachment),
          headers: { "Authorization" => "Bearer #{@token}" }

        assert_response :redirect
        assert response.location.present?
      end

      test "does not expose attachments from conversations the agent cannot access" do
        other_chat = @agent.account.chats.create!(model_id: "openrouter/auto", title: "Private conversation")
        other_message = other_chat.messages.create!(content: "Private file", role: "user", user: @user)
        other_message.attachments.attach(
          io: file_fixture("test_document.pdf").open,
          filename: "private.pdf",
          content_type: "application/pdf"
        )
        other_attachment = other_message.attachments_attachments.first

        get api_v1_conversation_message_attachment_url(other_chat, other_message, other_attachment),
          headers: { "Authorization" => "Bearer #{@token}" }

        assert_response :not_found
      end

      test "does not expose an attachment through the wrong message" do
        other_message = @chat.messages.create!(content: "No attachment here", role: "user", user: @user)

        get api_v1_conversation_message_attachment_url(@chat, other_message, @attachment),
          headers: { "Authorization" => "Bearer #{@token}" }

        assert_response :not_found
      end

    end
  end
end
