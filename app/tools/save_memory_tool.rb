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

    result = self.class.create_memory(@current_agent, content: content, memory_type: memory_type)

    if result[:error]
      error(result[:error])
    else
      success_response(result[:memory])
    end
  end

  # Determines if this tool can potentially recover from the given JSON structure.
  # The hallucinated response typically echoes the input parameters.
  def self.recoverable_from?(parsed_json)
    parsed_json.is_a?(Hash) &&
      parsed_json.key?("memory_type") &&
      parsed_json.key?("content")
  end

  # Attempts to recover this tool from a hallucinated response.
  # Returns { success: true, tool_name: ..., result: ... } or { error: "..." }
  def self.recover_from_hallucination(parsed_json, agent:, chat:)
    content = parsed_json["content"]
    memory_type = parsed_json["memory_type"]

    return { error: "Missing memory_type or content" } unless memory_type && content

    result = create_memory(agent, content: content, memory_type: memory_type)

    if result[:error]
      result
    else
      { success: true, tool_name: name, result: { memory_type: result[:memory].memory_type, content: result[:memory].content } }
    end
  end

  # Shared memory creation logic used by both execute and recover_from_hallucination.
  # Returns { memory: AgentMemory } or { error: "..." }
  def self.create_memory(agent, content:, memory_type:)
    return { error: "Invalid memory_type: #{memory_type}" } unless AgentMemory.memory_types.key?(memory_type)

    memory = agent.memories.create!(
      content: content.to_s.strip,
      memory_type: memory_type
    )

    { memory: memory }
  rescue ActiveRecord::RecordInvalid => e
    { error: "Failed to save memory: #{e.record.errors.full_messages.join(', ')}" }
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
