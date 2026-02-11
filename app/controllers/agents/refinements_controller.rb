class Agents::RefinementsController < ApplicationController

  include AgentScoped

  def create
    MemoryRefinementJob.perform_later(@agent.id)
    redirect_to edit_account_agent_path(current_account, @agent), notice: "Refinement session queued"
  end

end
