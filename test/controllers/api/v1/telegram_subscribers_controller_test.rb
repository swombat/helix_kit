require "test_helper"

module Api
  module V1
    class TelegramSubscribersControllerTest < ActionDispatch::IntegrationTest

      setup do
        @user = users(:confirmed_user)
        @agent = agents(:research_assistant)
        @api_key = ApiKey.generate_for(@user, name: "Agent Telegram subscribers", agent: @agent)
        @subscription = @agent.telegram_subscriptions.create!(
          user: users(:user_1),
          telegram_chat_id: 111,
          telegram_username: "daniel_t"
        )
      end

      test "lists subscribers with reachability and thread ids" do
        get api_v1_telegram_subscribers_url,
          headers: { "Authorization" => "Bearer #{@api_key.raw_token}" }

        assert_response :ok
        subscriber = JSON.parse(response.body).fetch("subscribers").first
        assert_equal @subscription.to_param, subscriber["thread_id"]
        assert_equal "daniel_t", subscriber["telegram_username"]
        assert_equal true, subscriber["active"]
      end

      test "includes blocked subscribers as inactive" do
        @subscription.mark_blocked!

        get api_v1_telegram_subscribers_url,
          headers: { "Authorization" => "Bearer #{@api_key.raw_token}" }

        assert_equal false, JSON.parse(response.body).dig("subscribers", 0, "active")
      end

    end
  end
end
