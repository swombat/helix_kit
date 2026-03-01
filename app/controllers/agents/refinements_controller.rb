class Agents::RefinementsController < ApplicationController

  include AgentScoped

  def create
    mode = params[:mode].presence_in(%w[full dedup_only]) || "full"
    MemoryRefinementJob.perform_later(@agent.id, mode:)
    label = mode == "dedup_only" ? "Dedup-only refinement" : "Full refinement"
    redirect_to edit_account_agent_path(current_account, @agent), notice: "#{label} session queued"
  end

end
