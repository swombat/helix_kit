class Accounts::AgentInitiationsController < ApplicationController

  require_feature_enabled :agents

  def create
    # Sweep: skip paused agents. Per-agent manual triggers (via the chat UI's
    # agent_trigger endpoint or the API) still work on paused agents because
    # those paths look up by id without the unpaused filter.
    current_account.agents.active.unpaused.each do |agent|
      delay = rand(1..60).seconds
      AgentInitiationDecisionJob.set(wait: delay).perform_later(agent)
    end

    redirect_to account_agents_path(current_account), notice: "Initiation triggered for all active, unpaused agents"
  end

end
