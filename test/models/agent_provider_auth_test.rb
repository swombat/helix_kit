require "test_helper"

class AgentProviderAuthTest < ActiveSupport::TestCase

  test "provider auth defaults to API key and records only display metadata" do
    agent = agents(:research_assistant)

    assert_equal "api_key", agent.provider_auth_mode("openai")

    agent.record_provider_connection!(
      "openai",
      email: "subscriber@example.com",
      plan: "Plus",
      status: "connected",
      connected_at: "2026-07-26T20:00:00Z",
      access_token: "must-not-be-stored"
    )

    assert_equal "oauth_account", agent.provider_auth_mode("openai")
    assert_equal(
      {
        "email" => "subscriber@example.com",
        "plan" => "Plus",
        "status" => "connected",
        "connected_at" => "2026-07-26T20:00:00Z"
      },
      agent.provider_connection("openai")
    )
    assert_not_includes agent.provider_connections.to_json, "must-not-be-stored"
  end

  test "disconnect clears display metadata and returns provider to API key mode" do
    agent = agents(:research_assistant)
    agent.record_provider_connection!("openai", status: "connected")

    agent.clear_provider_connection!("openai")

    assert_equal "api_key", agent.provider_auth_mode("openai")
    assert_empty agent.provider_connection("openai")
  end

end
