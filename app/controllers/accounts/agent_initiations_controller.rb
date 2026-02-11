class Accounts::AgentInitiationsController < ApplicationController

  require_feature_enabled :agents

  def create
    current_account.agents.active.each do |agent|
      delay = rand(1..60).seconds
      AgentInitiationDecisionJob.set(wait: delay).perform_later(agent)
    end

    redirect_to account_agents_path(current_account), notice: "Initiation triggered for all active agents"
  end

end
