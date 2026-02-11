require "test_helper"

class Agents::TelegramTestsControllerTest < ActionDispatch::IntegrationTest

  setup do
    @user = users(:user_1)
    @account = accounts(:personal_account)
    @agent = agents(:research_assistant)

    Setting.instance.update!(allow_agents: true)

    post login_path, params: {
      email_address: @user.email_address,
      password: "password123"
    }
    assert_redirected_to root_path
  end

  test "create redirects with error when telegram not configured" do
    post account_agent_telegram_test_path(@account, @agent)

    assert_redirected_to edit_account_agent_path(@account, @agent)
    assert_match(/not configured/, flash[:alert])
  end

  test "create redirects with error when no subscribers" do
    @agent.update!(telegram_bot_token: "123:ABC", telegram_bot_username: "test_bot")

    post account_agent_telegram_test_path(@account, @agent)

    assert_redirected_to edit_account_agent_path(@account, @agent)
    assert_match(/No users have connected/, flash[:alert])
  end

  test "create sends to subscribers and redirects with success" do
    @agent.update!(telegram_bot_token: "123:ABC", telegram_bot_username: "test_bot")
    @agent.telegram_subscriptions.create!(user: @user, telegram_chat_id: 12345)

    fake_response = Struct.new(:body).new({ "ok" => true, "result" => {} }.to_json)
    Net::HTTP.stub(:post, fake_response) do
      post account_agent_telegram_test_path(@account, @agent)
    end

    assert_redirected_to edit_account_agent_path(@account, @agent)
    assert_match(/Test notification sent to 1 subscriber/, flash[:notice])
  end

  test "create handles telegram API error" do
    @agent.update!(telegram_bot_token: "123:ABC", telegram_bot_username: "test_bot")
    @agent.telegram_subscriptions.create!(user: @user, telegram_chat_id: 12345)

    fake_response = Struct.new(:body).new({ "ok" => false, "description" => "Bot was blocked" }.to_json)
    Net::HTTP.stub(:post, fake_response) do
      post account_agent_telegram_test_path(@account, @agent)
    end

    assert_redirected_to edit_account_agent_path(@account, @agent)
    assert_match(/Telegram error/, flash[:alert])
  end

  test "requires authentication" do
    delete logout_path

    post account_agent_telegram_test_path(@account, @agent)
    assert_response :redirect
  end

  test "scopes to current account" do
    other_agent = agents(:other_account_agent)

    post account_agent_telegram_test_path(@account, other_agent)
    assert_response :not_found
  end

end
