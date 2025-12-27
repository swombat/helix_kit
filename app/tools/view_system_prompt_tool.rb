class ViewSystemPromptTool < RubyLLM::Tool

  description "View the system prompt and name of any agent in this group conversation, including yourself"

  param :agent_name, type: :string,
        desc: "Name of the agent to view (use 'self' or your own name to view your own prompt)",
        required: true

  def initialize(chat: nil, current_agent: nil)
    super()
    @chat = chat
    @current_agent = current_agent
  end

  def execute(agent_name:)
    return { error: "This tool only works in group conversations" } unless @chat&.group_chat?

    agent = find_agent(agent_name)
    return { error: "Agent '#{agent_name}' not found in this conversation" } unless agent

    {
      name: agent.name,
      system_prompt: agent.system_prompt || "(no system prompt set)",
      is_self: agent.id == @current_agent&.id
    }
  end

  private

  def find_agent(name)
    return @current_agent if name.downcase == "self"
    @chat.agents.find_by("LOWER(name) = ?", name.downcase)
  end

end
