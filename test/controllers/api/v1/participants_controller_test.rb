require "test_helper"

module Api
  module V1
    class ParticipantsControllerTest < ActionDispatch::IntegrationTest

      setup do
        @user = users(:user_1)
        @api_key = ApiKey.generate_for(@user, name: "Test")
        @token = @api_key.raw_token
        @account = @user.accounts.first
        @agent1 = agents(:research_assistant)
        @agent2 = agents(:code_reviewer)
        @agent3 = agents(:without_tools)

        @group_chat = Chat.create_with_message!(
          { account: @account, model_id: "openrouter/auto", title: "Group Chat", manual_responses: true },
          agent_ids: [ @agent1.id ]
        )

        @regular_chat = @account.chats.create!(
          model_id: "openrouter/auto",
          title: "Regular Chat"
        )
      end

      test "adds agent to group chat" do
        post api_v1_conversation_participants_url(@group_chat),
             params: { agent_id: @agent2.to_param },
             headers: { "Authorization" => "Bearer #{@token}" }
        assert_response :created

        json = JSON.parse(response.body)
        assert_equal "Code Reviewer", json["participant"]["name"]
        assert_equal 2, json["agents"].length

        last_message = @group_chat.messages.last
        assert_match /Code Reviewer has joined/, last_message.content
      end

      test "rejects adding agent already in chat" do
        post api_v1_conversation_participants_url(@group_chat),
             params: { agent_id: @agent1.to_param },
             headers: { "Authorization" => "Bearer #{@token}" }
        assert_response :unprocessable_entity

        json = JSON.parse(response.body)
        assert_match /already in this conversation/, json["error"]
      end

      test "rejects adding to non-group chat" do
        post api_v1_conversation_participants_url(@regular_chat),
             params: { agent_id: @agent2.to_param },
             headers: { "Authorization" => "Bearer #{@token}" }
        assert_response :unprocessable_entity
      end

      test "rejects adding inactive agent" do
        inactive = agents(:inactive_agent)
        post api_v1_conversation_participants_url(@group_chat),
             params: { agent_id: inactive.to_param },
             headers: { "Authorization" => "Bearer #{@token}" }
        assert_response :not_found
      end

      test "rejects adding to archived chat" do
        @group_chat.archive!
        post api_v1_conversation_participants_url(@group_chat),
             params: { agent_id: @agent2.to_param },
             headers: { "Authorization" => "Bearer #{@token}" }
        assert_response :unprocessable_entity
      end

      test "returns unauthorized without token" do
        post api_v1_conversation_participants_url(@group_chat),
             params: { agent_id: @agent2.to_param }
        assert_response :unauthorized
      end

    end
  end
end
