class SaveMemoryTool < RubyLLM::Tool

  description "Save a memory. Use 'journal' for short-term observations (fades after a week) or 'core' for permanent identity memories."

  param :content, type: :string,
        desc: "The memory to save (keep it concise)",
        required: true

  param :memory_type, type: :string,
        desc: "Either 'journal' or 'core'",
        required: true

  def initialize(chat: nil, current_agent: nil)
    super()
    @chat = chat
    @current_agent = current_agent
  end

  def execute(content:, memory_type:)
    return error("This tool only works in group conversations") unless @current_agent
    return error("memory_type must be 'journal' or 'core'") unless AgentMemory.memory_types.key?(memory_type)

    memory = @current_agent.memories.create!(
      content: content.to_s.strip,
      memory_type: memory_type
    )

    success_response(memory)
  rescue ActiveRecord::RecordInvalid => e
    error("Failed to save: #{e.record.errors.full_messages.join(', ')}")
  end

  private

  def error(msg) = { error: msg }

  def success_response(memory)
    response = {
      success: true,
      memory_type: memory.memory_type,
      content: memory.content
    }

    if memory.journal?
      response[:expires_around] = (memory.created_at + AgentMemory::JOURNAL_WINDOW).strftime("%Y-%m-%d")
    else
      response[:note] = "This memory is now part of your permanent identity"
    end

    response
  end

end
