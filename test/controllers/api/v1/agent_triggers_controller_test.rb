require "test_helper"

module Api
  module V1
    class AgentTriggersControllerTest < ActionDispatch::IntegrationTest

      setup do
        @user = users(:user_1)
        @api_key = ApiKey.generate_for(@user, name: "Test")
        @token = @api_key.raw_token
        @account = @user.accounts.first
        @agent1 = agents(:research_assistant)
        @agent2 = agents(:code_reviewer)

        @group_chat = Chat.create_with_message!(
          { account: @account, model_id: "openrouter/auto", title: "Group Chat", manual_responses: true },
          agent_ids: [ @agent1.id, @agent2.id ]
        )

        @regular_chat = @account.chats.create!(
          model_id: "openrouter/auto",
          title: "Regular Chat"
        )
      end

      test "triggers all agents in group chat" do
        assert_enqueued_with(job: AllAgentsResponseJob) do
          post api_v1_conversation_agent_trigger_url(@group_chat),
               headers: { "Authorization" => "Bearer #{@token}" }
        end
        assert_response :success

        json = JSON.parse(response.body)
        assert_equal 2, json["triggered"].length
      end

      test "triggers specific agent in group chat" do
        assert_enqueued_with(job: ManualAgentResponseJob) do
          post api_v1_conversation_agent_trigger_url(@group_chat),
               params: { agent_id: @agent1.to_param },
               headers: { "Authorization" => "Bearer #{@token}" }
        end
        assert_response :success

        json = JSON.parse(response.body)
        assert_equal 1, json["triggered"].length
        assert_equal "Research Assistant", json["triggered"].first["name"]
      end

      test "rejects trigger on non-group chat" do
        post api_v1_conversation_agent_trigger_url(@regular_chat),
             headers: { "Authorization" => "Bearer #{@token}" }
        assert_response :unprocessable_entity

        json = JSON.parse(response.body)
        assert_match /group chat/i, json["error"]
      end

      test "rejects trigger on archived chat" do
        @group_chat.archive!
        post api_v1_conversation_agent_trigger_url(@group_chat),
             headers: { "Authorization" => "Bearer #{@token}" }
        assert_response :unprocessable_entity
      end

      test "returns 404 for agent not in conversation" do
        other_agent = agents(:without_tools)
        post api_v1_conversation_agent_trigger_url(@group_chat),
             params: { agent_id: other_agent.to_param },
             headers: { "Authorization" => "Bearer #{@token}" }
        assert_response :not_found
      end

      test "returns unauthorized without token" do
        post api_v1_conversation_agent_trigger_url(@group_chat)
        assert_response :unauthorized
      end

      test "returns 404 for other account conversation" do
        other_user = users(:existing_user)
        other_account = other_user.accounts.first
        other_agent = agents(:other_account_agent)
        other_chat = Chat.create_with_message!(
          { account: other_account, model_id: "openrouter/auto", title: "Other Group", manual_responses: true },
          agent_ids: [ other_agent.id ]
        )

        post api_v1_conversation_agent_trigger_url(other_chat),
             headers: { "Authorization" => "Bearer #{@token}" }
        assert_response :not_found
      end

    end
  end
end
