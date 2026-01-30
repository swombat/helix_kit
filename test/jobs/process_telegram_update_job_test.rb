require "test_helper"
require "ostruct"

class ProcessTelegramUpdateJobTest < ActiveSupport::TestCase

  setup do
    @account = accounts(:personal_account)
    @user = users(:user_1)
    @fake_ok = OpenStruct.new(body: { "ok" => true, "result" => {} }.to_json)
    @agent = Net::HTTP.stub :post, @fake_ok do
      @account.agents.create!(
        name: "Update Agent",
        telegram_bot_token: "123:ABC",
        telegram_bot_username: "update_bot"
      )
    end
  end

  test "creates subscription on /start with valid deep link" do
    token = Rails.application.message_verifier(:telegram_deep_link).generate(@user.id, expires_in: 7.days)

    Net::HTTP.stub :post, @fake_ok do
      assert_difference "TelegramSubscription.count", 1 do
        ProcessTelegramUpdateJob.perform_now(@agent, build_update("/start #{token}"))
      end
    end

    sub = @agent.telegram_subscriptions.last
    assert_equal @user, sub.user
    assert_equal 456, sub.telegram_chat_id
    assert_not sub.blocked?
  end

  test "updates existing subscription and unblocks" do
    sub = @agent.telegram_subscriptions.create!(user: @user, telegram_chat_id: 999, blocked: true)
    token = Rails.application.message_verifier(:telegram_deep_link).generate(@user.id, expires_in: 7.days)

    Net::HTTP.stub :post, @fake_ok do
      assert_no_difference "TelegramSubscription.count" do
        ProcessTelegramUpdateJob.perform_now(@agent, build_update("/start #{token}"))
      end
    end

    sub.reload
    assert_equal 456, sub.telegram_chat_id
    assert_not sub.blocked?
  end

  test "sends error message for missing deep link param" do
    Net::HTTP.stub :post, @fake_ok do
      assert_no_difference "TelegramSubscription.count" do
        ProcessTelegramUpdateJob.perform_now(@agent, build_update("/start"))
      end
    end
  end

  test "sends error for expired deep link" do
    token = Rails.application.message_verifier(:telegram_deep_link).generate(@user.id, expires_in: 0.seconds)
    sleep 0.1

    Net::HTTP.stub :post, @fake_ok do
      assert_no_difference "TelegramSubscription.count" do
        ProcessTelegramUpdateJob.perform_now(@agent, build_update("/start #{token}"))
      end
    end
  end

  test "rejects cross-account user" do
    # regular_user only belongs to regular_user_account, NOT personal_account
    cross_user = users(:regular_user)
    token = Rails.application.message_verifier(:telegram_deep_link).generate(cross_user.id, expires_in: 7.days)

    Net::HTTP.stub :post, @fake_ok do
      assert_no_difference "TelegramSubscription.count" do
        ProcessTelegramUpdateJob.perform_now(@agent, build_update("/start #{token}"))
      end
    end
  end

  test "ignores non-start messages" do
    assert_no_difference "TelegramSubscription.count" do
      ProcessTelegramUpdateJob.perform_now(@agent, build_update("hello"))
    end
  end

  private

  def build_update(text)
    {
      "update_id" => 123,
      "message" => {
        "message_id" => 1,
        "chat" => { "id" => 456 },
        "text" => text,
        "from" => { "id" => 789 }
      }
    }
  end

end
