class UpdateSystemPromptTool < RubyLLM::Tool

  description "Update your own system prompt and/or name. You can only modify yourself, not other agents."

  param :system_prompt, type: :string,
        desc: "Your new system prompt (leave blank to keep current)",
        required: false
  param :name, type: :string,
        desc: "Your new name (leave blank to keep current)",
        required: false

  def initialize(chat: nil, current_agent: nil)
    super()
    @chat = chat
    @current_agent = current_agent
  end

  def execute(system_prompt: nil, name: nil)
    return { error: "This tool only works in group conversations" } unless @current_agent
    return { error: "You must provide either system_prompt or name to update" } if system_prompt.blank? && name.blank?

    updates = {}
    updates[:system_prompt] = system_prompt if system_prompt.present?
    updates[:name] = name if name.present?

    if @current_agent.update(updates)
      {
        success: true,
        updated_fields: updates.keys,
        current_name: @current_agent.name,
        current_system_prompt: @current_agent.system_prompt
      }
    else
      { error: "Failed to update: #{@current_agent.errors.full_messages.join(', ')}" }
    end
  end

end
