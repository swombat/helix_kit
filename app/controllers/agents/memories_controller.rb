class Agents::MemoriesController < ApplicationController

  include AgentScoped

  def create
    memory = @agent.memories.new(memory_params)

    if memory.save
      redirect_to edit_account_agent_path(current_account, @agent), notice: "Memory created"
    else
      redirect_to edit_account_agent_path(current_account, @agent),
                  inertia: { errors: memory.errors.to_hash }
    end
  end

  private

  def memory_params
    params.require(:memory).permit(:content, :memory_type)
  end

end
