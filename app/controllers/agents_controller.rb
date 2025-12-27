class AgentsController < ApplicationController

  require_feature_enabled :agents
  before_action :set_agent, only: [ :edit, :update, :destroy, :create_memory, :destroy_memory ]

  def index
    @agents = current_account.agents.by_name

    render inertia: "agents/index", props: {
      agents: @agents.as_json,
      grouped_models: grouped_models,
      available_tools: tools_for_frontend,
      colour_options: Agent::VALID_COLOURS,
      icon_options: Agent::VALID_ICONS,
      account: current_account.as_json
    }
  end

  def create
    @agent = current_account.agents.new(agent_params)

    if @agent.save
      audit("create_agent", @agent, **agent_params.to_h)
      redirect_to account_agents_path(current_account), notice: "Agent created"
    else
      redirect_to account_agents_path(current_account),
                  inertia: { errors: @agent.errors.to_hash }
    end
  end

  def edit
    render inertia: "agents/edit", props: {
      agent: @agent.as_json,
      memories: memories_for_display,
      grouped_models: grouped_models,
      available_tools: tools_for_frontend,
      colour_options: Agent::VALID_COLOURS,
      icon_options: Agent::VALID_ICONS,
      account: current_account.as_json
    }
  end

  def update
    if @agent.update(agent_params)
      audit("update_agent", @agent, **agent_params.to_h)
      redirect_to account_agents_path(current_account), notice: "Agent updated"
    else
      redirect_to edit_account_agent_path(current_account, @agent),
                  inertia: { errors: @agent.errors.to_hash }
    end
  end

  def destroy
    audit("destroy_agent", @agent)
    @agent.destroy!
    redirect_to account_agents_path(current_account), notice: "Agent deleted"
  end

  def destroy_memory
    memory = @agent.memories.find(params[:memory_id])
    memory.destroy!
    redirect_to edit_account_agent_path(current_account, @agent), notice: "Memory deleted"
  end

  def create_memory
    memory = @agent.memories.new(memory_params)

    if memory.save
      redirect_to edit_account_agent_path(current_account, @agent), notice: "Memory created"
    else
      redirect_to edit_account_agent_path(current_account, @agent),
                  inertia: { errors: memory.errors.to_hash }
    end
  end

  private

  def set_agent
    @agent = current_account.agents.find(params[:id])
  end

  def agent_params
    params.require(:agent).permit(:name, :system_prompt, :model_id, :active, :colour, :icon, enabled_tools: [])
  end

  def memory_params
    params.require(:memory).permit(:content, :memory_type)
  end

  def grouped_models
    Chat::MODELS.group_by { |m| m[:group] || "Other" }
  end

  def tools_for_frontend
    Agent.available_tools.map do |tool|
      {
        class_name: tool.name,
        name: tool.name.underscore.humanize.sub(/ tool$/i, ""),
        description: tool.try(:description)
      }
    end
  end

  def memories_for_display
    @agent.memories.recent_first.limit(100).map do |m|
      {
        id: m.id,
        content: m.content,
        memory_type: m.memory_type,
        created_at: m.created_at.strftime("%Y-%m-%d %H:%M"),
        expired: m.expired?
      }
    end
  end

end
