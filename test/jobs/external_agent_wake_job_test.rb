require "test_helper"
require "webmock/minitest"

class ExternalAgentWakeJobTest < ActiveJob::TestCase

  setup do
    @agent = agents(:research_assistant)
    @agent.update!(
      runtime: "external",
      uuid: SecureRandom.uuid_v7,
      endpoint_url: "https://agent.example.com",
      trigger_bearer_token: "tr_valid",
      health_state: "healthy",
      consecutive_health_failures: 0
    )
  end

  test "sends hourly wake invitations to external agents" do
    request = stub_request(:post, "https://agent.example.com/trigger")
      .with(
        headers: { "Authorization" => "Bearer tr_valid" },
        body: lambda { |body|
          parsed = JSON.parse(body)
          parsed["trigger_kind"] == "wake" &&
            parsed["conversation_id"].nil? &&
            parsed["session_id"] == "#{@agent.uuid}-wake" &&
            parsed["request"].include?("hourly self-directed session")
        }
      )
      .to_return(status: 200, body: { status: "ok" }.to_json)

    ExternalAgentWakeJob.perform_now

    assert_requested request
  end

  test "does not wake offline agents" do
    @agent.update!(runtime: "offline")

    ExternalAgentWakeJob.perform_now

    assert_not_requested :post, "https://agent.example.com/trigger"
  end

end
