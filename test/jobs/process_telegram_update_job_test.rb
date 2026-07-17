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
    # Use memory store so deep link tokens persist within the test
    @original_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
  end

  teardown do
    Rails.cache = @original_cache
  end

  test "creates subscription on /start with valid deep link" do
    token = "test_token_#{SecureRandom.hex(8)}"
    Rails.cache.write("telegram_deep_link:#{token}", { user_id: @user.id, agent_id: @agent.id }, expires_in: 7.days)

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
    token = "test_token_#{SecureRandom.hex(8)}"
    Rails.cache.write("telegram_deep_link:#{token}", { user_id: @user.id, agent_id: @agent.id }, expires_in: 7.days)

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
    token = "test_token_#{SecureRandom.hex(8)}"
    Rails.cache.write("telegram_deep_link:#{token}", { user_id: @user.id, agent_id: @agent.id }, expires_in: 0.seconds)
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
    token = "test_token_#{SecureRandom.hex(8)}"
    Rails.cache.write("telegram_deep_link:#{token}", { user_id: cross_user.id, agent_id: @agent.id }, expires_in: 7.days)

    Net::HTTP.stub :post, @fake_ok do
      assert_no_difference "TelegramSubscription.count" do
        ProcessTelegramUpdateJob.perform_now(@agent, build_update("/start #{token}"))
      end
    end
  end

  test "ignores non-start messages" do
    assert_no_difference [ "TelegramSubscription.count", "TelegramMessage.count" ] do
      ProcessTelegramUpdateJob.perform_now(@agent, build_update("hello"))
    end
  end

  test "stores a direct message from a subscribed user" do
    subscription = @agent.telegram_subscriptions.create!(user: @user, telegram_chat_id: 456)

    assert_difference "TelegramMessage.count", 1 do
      assert_no_enqueued_jobs only: TelegramAgentTriggerJob do
        ProcessTelegramUpdateJob.perform_now(@agent, build_update("hello", username: "daniel_t"))
      end
    end

    telegram_message = subscription.telegram_messages.last
    assert_equal "user", telegram_message.role
    assert_equal "hello", telegram_message.text
    assert_equal "daniel_t", telegram_message.sender_username
    assert_equal "daniel_t", subscription.reload.telegram_username
  end

  test "triggers an external agent for a subscribed direct message" do
    @agent.update!(
      runtime: "external",
      endpoint_url: "https://agent.example.com",
      trigger_bearer_token: "tr_valid"
    )
    @agent.telegram_subscriptions.create!(user: @user, telegram_chat_id: 456)

    assert_enqueued_with(job: TelegramAgentTriggerJob) do
      ProcessTelegramUpdateJob.perform_now(@agent, build_update("wake up"))
    end
  end

  test "does not trigger twice for a duplicate Telegram update" do
    @agent.update!(
      runtime: "external",
      endpoint_url: "https://agent.example.com",
      trigger_bearer_token: "tr_valid"
    )
    @agent.telegram_subscriptions.create!(user: @user, telegram_chat_id: 456)
    update = build_update("once")

    assert_difference "TelegramMessage.count", 1 do
      2.times { ProcessTelegramUpdateJob.perform_now(@agent, update) }
    end
    assert_equal 1, enqueued_jobs.count { |job| job["job_class"] == "TelegramAgentTriggerJob" }
  end

  private

  def build_update(text, username: nil)
    {
      "update_id" => 123,
      "message" => {
        "message_id" => 1,
        "date" => Time.current.to_i,
        "chat" => { "id" => 456, "type" => "private" },
        "text" => text,
        "from" => { "id" => 789, "username" => username }
      }
    }
  end

end
