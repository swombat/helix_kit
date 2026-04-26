class Agents::RefinementsController < ApplicationController

  include AgentScoped

  def create
    mode = params[:mode].presence_in(%w[full dedup_only]) || "full"
    # Manual user trigger from the agent edit page — bypass the paused check
    # so refining a paused agent still works on demand. Cron-driven refinement
    # leaves force unset and respects paused.
    MemoryRefinementJob.perform_later(@agent.id, mode:, force: true)
    label = mode == "dedup_only" ? "Dedup-only refinement" : "Full refinement"
    redirect_to edit_account_agent_path(current_account, @agent), notice: "#{label} session queued"
  end

end
