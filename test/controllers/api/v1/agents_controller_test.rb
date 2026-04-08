require "test_helper"

module Api
  module V1
    class AgentsControllerTest < ActionDispatch::IntegrationTest

      setup do
        @user = users(:user_1)
        @api_key = ApiKey.generate_for(@user, name: "Test")
        @token = @api_key.raw_token
        @account = @user.accounts.first
      end

      test "returns unauthorized without token" do
        get api_v1_agents_url
        assert_response :unauthorized
      end

      test "lists active agents" do
        get api_v1_agents_url, headers: { "Authorization" => "Bearer #{@token}" }
        assert_response :success

        json = JSON.parse(response.body)
        agents = json["agents"]
        assert agents.is_a?(Array)

        names = agents.map { |a| a["name"] }
        assert_includes names, "Research Assistant"
        assert_includes names, "Code Reviewer"
        assert_not_includes names, "Inactive Agent"
      end

      test "each agent has expected fields" do
        get api_v1_agents_url, headers: { "Authorization" => "Bearer #{@token}" }
        json = JSON.parse(response.body)
        agent = json["agents"].first

        assert agent["id"].present?
        assert agent["name"].present?
        assert agent.key?("model")
        assert agent.key?("colour")
        assert agent.key?("icon")
        assert_equal true, agent["active"]
      end

      test "shows a single agent" do
        agent = agents(:research_assistant)
        get api_v1_agent_url(agent), headers: { "Authorization" => "Bearer #{@token}" }
        assert_response :success

        json = JSON.parse(response.body)
        assert_equal "Research Assistant", json["agent"]["name"]
      end

      test "returns 404 for other account agent" do
        agent = agents(:other_account_agent)
        get api_v1_agent_url(agent), headers: { "Authorization" => "Bearer #{@token}" }
        assert_response :not_found
      end

    end
  end
end
