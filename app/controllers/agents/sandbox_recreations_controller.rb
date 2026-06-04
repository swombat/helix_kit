class Agents::SandboxRecreationsController < ApplicationController

  include AgentScoped

  before_action :require_account_owner!

  def create
    unless @agent.externally_hosted?
      redirect_to edit_account_agent_path(current_account, @agent, tab: "hosting"), alert: "Only hosted agents have sandboxes to recreate"
      return
    end

    HostedAgentRuntimeReconcileJob.perform_later(@agent.id)
    redirect_to edit_account_agent_path(current_account, @agent, tab: "hosting"), notice: "Sandbox recreation queued for #{@agent.name}. Identity and Chaos volumes will be preserved."
  end

end
