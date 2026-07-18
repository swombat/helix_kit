class ExternalAgentWakeJob < ApplicationJob

  queue_as :default

  def perform(extra_half_hour = false)
    wakeable_agents(extra_half_hour: extra_half_hour).find_each do |agent|
      ExternalAgentWakeRequest.new(agent: agent).call
    end
  end

  private

  def wakeable_agents(extra_half_hour:)
    scope = Agent.active
                 .unpaused
                 .where(runtime: "external")
                 .where(scheduled_wakes_enabled: true)
                 .where.not(trigger_bearer_token: [ nil, "" ])
    extra_half_hour ? scope.where(half_hourly_wake: true) : scope
  end

end
