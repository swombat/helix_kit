class AgentHealthCheckJob < ApplicationJob

  require "net/http"

  queue_as :default

  def perform
    Agent.externally_hosted.find_each do |agent|
      apply_result(agent, healthy?(agent))
    end
  end

  private

  def healthy?(agent)
    return false if agent.endpoint_url.blank?

    uri = URI("#{agent.endpoint_url.to_s.delete_suffix('/')}/health")
    response = Net::HTTP.get_response(uri)
    response.code == "200"
  rescue StandardError
    false
  end

  def apply_result(agent, healthy)
    if healthy
      agent.update!(
        last_health_check_at: Time.current,
        health_state: "healthy",
        consecutive_health_failures: 0,
        runtime: agent.offline? ? "external" : agent.runtime
      )
    else
      failures = agent.consecutive_health_failures + 1
      attrs = {
        last_health_check_at: Time.current,
        health_state: "unhealthy",
        consecutive_health_failures: failures
      }
      attrs[:runtime] = "offline" if failures >= 6 && agent.external?
      agent.update!(attrs)
    end
  end

end
