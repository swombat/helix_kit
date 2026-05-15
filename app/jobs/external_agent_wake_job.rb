class ExternalAgentWakeJob < ApplicationJob

  queue_as :default

  def perform
    wakeable_agents.find_each do |agent|
      ExternalAgentWakeRequest.new(agent: agent).call
    end
  end

  private

  def wakeable_agents
    Agent.active
         .unpaused
         .where(runtime: "external")
         .where.not(endpoint_url: [ nil, "" ])
  end

end
