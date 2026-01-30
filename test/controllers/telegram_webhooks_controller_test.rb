require "test_helper"
require "ostruct"

class TelegramWebhooksControllerTest < ActionDispatch::IntegrationTest

  setup do
    fake_ok = OpenStruct.new(body: { "ok" => true }.to_json)
    @agent = Net::HTTP.stub :post, fake_ok do
      accounts(:personal_account).agents.create!(
        name: "Webhook Agent",
        telegram_bot_token: "123:ABC",
        telegram_bot_username: "test_bot"
      )
    end
    @token = @agent.telegram_webhook_token
    @secret = @agent.telegram_webhook_secret
  end

  test "returns 404 for unknown webhook token" do
    post "/telegram/webhook/unknown_token",
         params: valid_update.to_json,
         headers: { "Content-Type" => "application/json" }
    assert_response :not_found
  end

  test "returns 401 for invalid secret token" do
    post "/telegram/webhook/#{@token}",
         params: valid_update.to_json,
         headers: {
           "Content-Type" => "application/json",
           "X-Telegram-Bot-Api-Secret-Token" => "wrong_secret"
         }
    assert_response :unauthorized
  end

  test "returns 200 and enqueues job for valid request" do
    assert_enqueued_with(job: ProcessTelegramUpdateJob) do
      post "/telegram/webhook/#{@token}",
           params: valid_update.to_json,
           headers: {
             "Content-Type" => "application/json",
             "X-Telegram-Bot-Api-Secret-Token" => @secret
           }
    end
    assert_response :ok
  end

  private

  def valid_update
    {
      update_id: 123,
      message: {
        message_id: 1,
        chat: { id: 456 },
        text: "/start sometoken",
        from: { id: 789 }
      }
    }
  end

end
