class AgentsController < ApplicationController

  require_feature_enabled :agents
  before_action :set_agent, only: [ :edit, :update, :destroy, :create_memory, :destroy_memory, :send_test_telegram ]

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
      agent: @agent.as_json.merge(
        "telegram_bot_token" => @agent.telegram_bot_token
      ),
      telegram_deep_link: @agent.telegram_configured? ? @agent.telegram_deep_link_for(Current.user) : nil,
      telegram_subscriber_count: @agent.telegram_subscriptions.active.count,
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

  def trigger_initiation
    current_account.agents.active.each do |agent|
      delay = rand(1..60).seconds
      AgentInitiationDecisionJob.set(wait: delay).perform_later(agent)
    end

    redirect_to account_agents_path(current_account), notice: "Initiation triggered for all active agents"
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

  def send_test_telegram
    unless @agent.telegram_configured?
      return redirect_to edit_account_agent_path(current_account, @agent), alert: "Telegram bot is not configured."
    end

    subscriptions = @agent.telegram_subscriptions.active
    if subscriptions.none?
      return redirect_to edit_account_agent_path(current_account, @agent), alert: "No users have connected to this bot yet."
    end

    subscriptions.each do |sub|
      @agent.telegram_send_message(sub.telegram_chat_id, "Test notification from #{@agent.name}.\n\nIf you see this, Telegram notifications are working!")
    end

    redirect_to edit_account_agent_path(current_account, @agent), notice: "Test notification sent to #{subscriptions.count} subscriber(s)."
  rescue TelegramNotifiable::TelegramError => e
    redirect_to edit_account_agent_path(current_account, @agent), alert: "Telegram error: #{e.message}"
  end

  private

  def set_agent
    @agent = current_account.agents.find(params[:id])
  end

  def agent_params
    params.require(:agent).permit(
      :name, :system_prompt, :reflection_prompt, :memory_reflection_prompt,
      :model_id, :active, :colour, :icon,
      :thinking_enabled, :thinking_budget,
      :telegram_bot_token, :telegram_bot_username,
      enabled_tools: []
    )
  end

  def memory_params
    params.require(:memory).permit(:content, :memory_type)
  end

  def grouped_models
    Chat::MODELS.group_by { |m| m[:group] || "Other" }.transform_values do |models|
      models.map do |m|
        {
          model_id: m[:model_id],
          label: m[:label],
          supports_thinking: m.dig(:thinking, :supported) == true
        }
      end
    end
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
        expired: m.expired?,
        age_in_days: ((Time.current - m.created_at) / 1.day).floor
      }
    end
  end

end
