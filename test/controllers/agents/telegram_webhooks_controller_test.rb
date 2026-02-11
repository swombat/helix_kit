require "test_helper"

class Agents::TelegramWebhooksControllerTest < ActionDispatch::IntegrationTest

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
    post account_agent_telegram_webhook_path(@account, @agent)

    assert_redirected_to edit_account_agent_path(@account, @agent)
    assert_match(/not configured/, flash[:alert])
  end

  test "create registers and redirects with success" do
    @agent.update!(telegram_bot_token: "123:ABC", telegram_bot_username: "test_bot")

    fake_set_response = Struct.new(:body).new({ "ok" => true }.to_json)
    fake_info_response = Struct.new(:body).new({ "ok" => true, "result" => { "url" => "https://example.com/webhook" } }.to_json)

    call_count = 0
    fake_post = lambda do |_uri, _body, _headers|
      call_count += 1
      call_count == 1 ? fake_set_response : fake_info_response
    end

    Net::HTTP.stub(:post, fake_post) do
      post account_agent_telegram_webhook_path(@account, @agent)
    end

    assert_redirected_to edit_account_agent_path(@account, @agent)
    assert_match(/Webhook registered/, flash[:notice])
  end

  test "requires authentication" do
    delete logout_path

    post account_agent_telegram_webhook_path(@account, @agent)
    assert_response :redirect
  end

  test "scopes to current account" do
    other_agent = agents(:other_account_agent)

    post account_agent_telegram_webhook_path(@account, other_agent)
    assert_response :not_found
  end

end
