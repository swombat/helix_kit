require "test_helper"

module Api
  module V1
    class AttentionsControllerTest < ActionDispatch::IntegrationTest

      setup do
        @user = users(:confirmed_user)
        @agent = agents(:research_assistant)
        @api_key = ApiKey.generate_for(@user, name: "Agent attention", agent: @agent)
        @chat = Chat.new(
          account: @agent.account,
          title: "Attention chat",
          manual_responses: true,
          model_id_string: "openrouter/auto"
        )
        @chat.agents << @agent
        @chat.save!
        @chat.messages.create!(role: "user", user: users(:user_1), content: "Please look")
      end

      test "returns a cross-channel attention feed for an agent key" do
        get api_v1_attention_url,
          headers: { "Authorization" => "Bearer #{@api_key.raw_token}" }

        assert_response :ok
        json = JSON.parse(response.body)
        assert_equal({ "helixkit" => "ok", "telegram" => "ok" }, json["checked"])
        assert_equal 1, json.dig("counts", "total")
        assert_equal 1, json.dig("counts", "by_author_type", "human")
        assert_equal @chat.to_param, json.dig("items", 0, "thread_id")
      end

      test "rejects user-scoped keys" do
        user_key = ApiKey.generate_for(@user, name: "User attention")

        get api_v1_attention_url,
          headers: { "Authorization" => "Bearer #{user_key.raw_token}" }

        assert_response :forbidden
      end

      test "rejects requests without a key" do
        get api_v1_attention_url

        assert_response :unauthorized
      end

    end
  end
end
