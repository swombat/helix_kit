require "test_helper"
require "ostruct"

module Api
  module V1
    class TelegramMessagesControllerTest < ActionDispatch::IntegrationTest

      setup do
        @user = users(:confirmed_user)
        @agent = agents(:research_assistant)
        @agent.update!(telegram_bot_token: "123:ABC", telegram_bot_username: "test_bot")
        @api_key = ApiKey.generate_for(@user, name: "Agent Telegram", agent: @agent)
        @token = @api_key.raw_token
        @subscriber = users(:user_1)
        @subscriber.profile.update!(first_name: "Daniel", last_name: "Tester")
        @subscription = @agent.telegram_subscriptions.create!(user: @subscriber, telegram_chat_id: 111)
      end

      test "agent-scoped key sends telegram message to matching subscriber" do
        posts = []
        fake_ok = OpenStruct.new(body: { "ok" => true }.to_json)

        Net::HTTP.stub :post, ->(uri, body, headers) { posts << [ uri, JSON.parse(body), headers ]; fake_ok } do
          post api_v1_telegram_messages_url,
            params: { recipient: "daniel", text: "Hello <friend>" },
            headers: { "Authorization" => "Bearer #{@token}" }
        end

        assert_response :created
        json = JSON.parse(response.body)
        assert_equal [ @subscriber.email_address ], json["delivered"].map { |recipient| recipient["email"] }
        assert_empty json["blocked"]
        assert_empty json["failures"]
        assert_equal 1, posts.length
        assert_equal "https://api.telegram.org/bot#{@agent.telegram_bot_token}/sendMessage", posts.first[0].to_s
        assert_equal 111, posts.first[1]["chat_id"]
        assert_equal "Hello &lt;friend&gt;", posts.first[1]["text"]
      end

      test "user-scoped key cannot send telegram messages" do
        user_key = ApiKey.generate_for(@user, name: "User key")

        post api_v1_telegram_messages_url,
          params: { recipient: "daniel", text: "Hello" },
          headers: { "Authorization" => "Bearer #{user_key.raw_token}" }

        assert_response :forbidden
      end

      test "returns not found when recipient does not match active subscriber" do
        post api_v1_telegram_messages_url,
          params: { recipient: "paulina", text: "Hello" },
          headers: { "Authorization" => "Bearer #{@token}" }

        assert_response :not_found
      end

      test "requires configured telegram bot" do
        @agent.update!(telegram_bot_token: nil, telegram_bot_username: nil)

        post api_v1_telegram_messages_url,
          params: { recipient: "daniel", text: "Hello" },
          headers: { "Authorization" => "Bearer #{@token}" }

        assert_response :unprocessable_entity
      end

    end
  end
end
