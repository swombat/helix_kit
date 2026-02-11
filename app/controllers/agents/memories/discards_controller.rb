class Agents::Memories::DiscardsController < ApplicationController

  include AgentScoped

  before_action :set_memory

  def create
    if @memory.discard
      redirect_to edit_account_agent_path(current_account, @agent), notice: "Memory discarded"
    else
      redirect_to edit_account_agent_path(current_account, @agent), alert: "Cannot discard a constitutional memory"
    end
  end

  def destroy
    @memory.undiscard!
    redirect_to edit_account_agent_path(current_account, @agent), notice: "Memory restored"
  end

  private

  def set_memory
    @memory = @agent.memories.find(params[:memory_id])
  end

end
