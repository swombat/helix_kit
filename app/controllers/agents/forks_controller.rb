class Agents::ForksController < ApplicationController

  include AgentScoped

  def create
    forked = @agent.fork!(
      name: params[:name].presence,
      model_id: params[:model_id].presence
    )

    audit("fork_agent", forked,
          source_agent_id: @agent.id,
          source_agent_name: @agent.name,
          memories_copied: forked.memories.kept.count,
          new_model_id: forked.model_id)

    redirect_to edit_account_agent_path(current_account, forked),
                notice: "Forked #{@agent.name} as #{forked.name}"
  rescue ActiveRecord::RecordInvalid => e
    redirect_to account_agents_path(current_account),
                inertia: { errors: e.record.errors.to_hash }
  end

end
