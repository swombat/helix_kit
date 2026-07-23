class Agents::OrientationRetriesController < ApplicationController

  include AgentScoped

  def create
    unless @agent.born_hosted? && @agent.external? && @agent.health_state == "healthy"
      redirect_to onboarding_account_agent_path(current_account, @agent), alert: "The runtime must be healthy before orientation"
      return
    end

    @agent.update!(
      orientation_completed_at: nil,
      orientation_last_error: nil,
      orientation_last_error_at: nil
    )
    OrientNewAgentJob.perform_later(@agent.id)
    redirect_to onboarding_account_agent_path(current_account, @agent), notice: "Another orientation wake has been queued"
  end

end
