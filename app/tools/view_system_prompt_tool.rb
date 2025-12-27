class ViewSystemPromptTool < RubyLLM::Tool

  description "View your own system prompt and name"

  def initialize(chat: nil, current_agent: nil)
    super()
    @chat = chat
    @current_agent = current_agent
  end

  def execute
    return { error: "This tool only works in group conversations" } unless @chat&.group_chat?
    return { error: "No current agent context" } unless @current_agent

    {
      name: @current_agent.name,
      system_prompt: @current_agent.system_prompt || "(no system prompt set)"
    }
  end

end
