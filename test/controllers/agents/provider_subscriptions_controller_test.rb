require "test_helper"

class Agents::ProviderSubscriptionsControllerTest < ActionDispatch::IntegrationTest

  setup do
    @user = users(:user_1)
    @account = accounts(:team_account)
    @agent = agents(:other_account_agent)
    @agent.update!(
      model_id: "openai/gpt-5",
      runtime: "external",
      health_state: "healthy",
      trigger_bearer_token: "trigger-secret",
      endpoint_url: "https://agent.example.com"
    )
    Setting.instance.update!(allow_agents: true)
    sign_in(@user)
  end

  test "start relays the one-time code without storing it" do
    client = Object.new
    client.define_singleton_method(:start) do |provider:|
      {
        "status" => "pending",
        "provider" => provider,
        "verification_url" => "https://auth.example.com/device",
        "user_code" => "ABCD-EFGH",
        "expires_in" => 900
      }
    end

    AgentProviderAuthClient.stub(:new, client) do
      post account_agent_provider_subscription_path(@account, @agent),
           params: { provider: "openai" },
           as: :json
    end

    assert_response :success
    assert_equal "ABCD-EFGH", response.parsed_body.fetch("user_code")
    assert_equal "api_key", @agent.reload.provider_auth_mode("openai")
    assert_not_includes @agent.provider_connections.to_json, "ABCD-EFGH"
    assert_not_includes AuditLog.where(auditable: @agent).pluck(:data).to_json, "ABCD-EFGH"
  end

  test "status persists display metadata but no credentials" do
    client = Object.new
    client.define_singleton_method(:status) do |provider:|
      {
        "status" => "connected",
        "provider" => provider,
        "email" => "subscriber@example.com",
        "plan" => "Plus"
      }
    end

    AgentProviderAuthClient.stub(:new, client) do
      get account_agent_provider_subscription_path(@account, @agent),
          params: { provider: "openai" },
          as: :json
    end

    assert_response :success
    assert_equal "oauth_account", @agent.reload.provider_auth_mode("openai")
    assert_equal "subscriber@example.com", @agent.provider_connection("openai").fetch("email")
    assert_equal "Plus", @agent.provider_connection("openai").fetch("plan")
  end

  test "capabilities are read from the agent runtime" do
    client = Object.new
    client.define_singleton_method(:capabilities) do
      {
        "providers" => {
          "openai" => { "api_key" => true, "oauth_account" => true },
          "xai" => { "api_key" => true, "oauth_account" => true }
        },
        "chaos_version" => "chaos 1.2.3"
      }
    end

    AgentProviderAuthClient.stub(:new, client) do
      get account_agent_provider_subscription_path(@account, @agent),
          params: { capabilities: true },
          as: :json
    end

    assert_response :success
    assert_equal true, response.parsed_body.dig("providers", "xai", "oauth_account")
    assert_equal "api_key", @agent.reload.provider_auth_mode("openai")
  end

  test "disconnect clears connection metadata" do
    @agent.record_provider_connection!("openai", status: "connected", email: "subscriber@example.com")
    client = Object.new
    client.define_singleton_method(:disconnect) { |provider:| { "status" => "none", "provider" => provider } }

    AgentProviderAuthClient.stub(:new, client) do
      delete account_agent_provider_subscription_path(@account, @agent),
             params: { provider: "openai" },
             as: :json
    end

    assert_response :success
    assert_equal "api_key", @agent.reload.provider_auth_mode("openai")
    assert_empty @agent.provider_connection("openai")
  end

end
