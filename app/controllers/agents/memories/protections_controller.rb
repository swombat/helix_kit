class Agents::Memories::ProtectionsController < ApplicationController

  include AgentScoped

  before_action :set_memory

  def create
    @memory.update!(constitutional: true)
    audit("memory_protected", @memory)
    redirect_to edit_account_agent_path(current_account, @agent), notice: "Memory protected"
  end

  def destroy
    @memory.update!(constitutional: false)
    audit("memory_unprotected", @memory)
    redirect_to edit_account_agent_path(current_account, @agent), notice: "Memory unprotected"
  end

  private

  def set_memory
    @memory = @agent.memories.find(params[:memory_id])
  end

end
