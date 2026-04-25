class Agents::PredecessorsController < ApplicationController

  include AgentScoped

  def create
    from_model = @agent.model_id
    predecessor = @agent.upgrade_with_predecessor!(
      to_model: params[:to_model],
      predecessor_name: params[:predecessor_name].presence
    )

    audit("create_predecessor", predecessor,
          successor_agent_id: @agent.id,
          successor_agent_name: @agent.name,
          from_model: from_model,
          to_model: @agent.model_id,
          memories_copied: predecessor.memories.kept.count)

    redirect_to edit_account_agent_path(current_account, @agent),
                notice: "Upgraded #{@agent.name} to #{@agent.model_label}; preserved past-self as #{predecessor.name}"
  rescue ArgumentError => e
    redirect_to account_agents_path(current_account), alert: e.message
  rescue ActiveRecord::RecordInvalid => e
    redirect_to account_agents_path(current_account),
                inertia: { errors: e.record.errors.to_hash }
  end

end
