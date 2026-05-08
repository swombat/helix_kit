require "test_helper"
require "webmock/minitest"

class AgentHealthCheckJobTest < ActiveJob::TestCase

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

  test "marks external agent unhealthy and offline after repeated failures" do
    stub_request(:get, "https://agent.example.com/health").to_return(status: 500)

    6.times { AgentHealthCheckJob.perform_now }

    @agent.reload
    assert_equal "offline", @agent.runtime
    assert_equal "unhealthy", @agent.health_state
    assert_equal 6, @agent.consecutive_health_failures
    assert_not_nil @agent.last_health_check_at
  end

  test "returns offline agent to external after successful health check" do
    @agent.update!(runtime: "offline", health_state: "unhealthy", consecutive_health_failures: 6)
    stub_request(:get, "https://agent.example.com/health").to_return(status: 200, body: "{}")

    AgentHealthCheckJob.perform_now

    @agent.reload
    assert_equal "external", @agent.runtime
    assert_equal "healthy", @agent.health_state
    assert_equal 0, @agent.consecutive_health_failures
  end

end
