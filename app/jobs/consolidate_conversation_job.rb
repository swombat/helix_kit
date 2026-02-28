class ConsolidateConversationJob < ApplicationJob

  include SelectsLlmProvider

  IDLE_THRESHOLD = 6.hours
  CHUNK_TARGET_TOKENS = 100_000

  def perform(chat)
    return unless eligible?(chat)

    messages = messages_to_consolidate(chat)
    return if messages.empty?

    chunks = chunk_messages(messages)

    chat.agents.find_each do |agent|
      extract_memories_for_agent(agent, chunks)
    end

    mark_consolidated!(chat, messages.last)
  end

  private

  def eligible?(chat)
    chat.group_chat? && !recently_active?(chat)
  end

  def recently_active?(chat)
    chat.messages.where("created_at > ?", IDLE_THRESHOLD.ago).exists?
  end

  def messages_to_consolidate(chat)
    scope = chat.messages.includes(:user, :agent).order(:created_at, :id)

    if chat.last_consolidated_message_id
      scope = scope.where("id > ?", chat.last_consolidated_message_id)
    end

    scope.to_a
  end

  def chunk_messages(messages)
    chunks = []
    current_chunk = []
    current_tokens = 0

    messages.each do |msg|
      msg_tokens = token_count(message_text(msg))

      if current_tokens + msg_tokens > CHUNK_TARGET_TOKENS && current_chunk.any?
        chunks << current_chunk
        current_chunk = []
        current_tokens = 0
      end

      current_chunk << msg
      current_tokens += msg_tokens
    end

    chunks << current_chunk if current_chunk.any?
    chunks
  end

  def extract_memories_for_agent(agent, chunks)
    existing_core = agent.memories.core.pluck(:content)

    chunks.each do |chunk|
      extracted = call_extraction_llm(agent, chunk, existing_core)
      create_memories(agent, extracted)

      # Track new core memories for subsequent chunks
      existing_core += extracted[:core] if extracted[:core].present?
    end
  end

  def call_extraction_llm(agent, messages, existing_core)
    prompt = build_prompt(agent, existing_core)
    conversation_text = messages.map { |m| message_text(m) }.join("\n\n")

    # Agent uses its own model for extraction
    provider_config = llm_provider_for(agent.model_id)
    llm = RubyLLM.chat(
      model: provider_config[:model_id],
      provider: provider_config[:provider],
      assume_model_exists: true
    )

    response = llm.ask("#{prompt}\n\n---\n\nConversation:\n\n#{conversation_text}")
    parse_extraction_response(response)
  rescue => e
    Rails.logger.error "Memory extraction failed for agent #{agent.id}: #{e.message}"
    { journal: [], core: [] }
  end

  def build_prompt(agent, existing_core)
    base_prompt = agent.reflection_prompt.presence || EXTRACTION_PROMPT

    formatted_prompt = format(base_prompt,
      system_prompt: agent.system_prompt.presence || "You are #{agent.name}.",
      existing_memories: format_existing_memories(existing_core)
    )

    "#{formatted_prompt}\n\n#{JSON_FORMAT_INSTRUCTION}"
  end

  def create_memories(agent, extracted)
    extracted[:journal]&.each do |content|
      agent.memories.create(content: content.strip, memory_type: :journal)
    end

    extracted[:core]&.each do |content|
      agent.memories.create(content: content.strip, memory_type: :core)
    end
  end

  def mark_consolidated!(chat, last_message)
    chat.update_columns(
      last_consolidated_at: Time.current,
      last_consolidated_message_id: last_message.id
    )
  end

  def token_count(text)
    OpenAI.rough_token_count(text.to_s)
  end

  def message_text(msg)
    prefix = msg.agent&.name || msg.user&.full_name || msg.user&.email_address&.split("@")&.first || "User"
    "[#{prefix}]: #{msg.content}"
  end

  def format_existing_memories(memories)
    return "None yet." if memories.empty?
    memories.map { |m| "- #{m}" }.join("\n")
  end

  def parse_extraction_response(response)
    json = JSON.parse(response.content)
    {
      journal: Array(json["journal"]).map(&:to_s).reject(&:blank?),
      core: Array(json["core"]).map(&:to_s).reject(&:blank?)
    }
  rescue JSON::ParserError => e
    Rails.logger.warn "Failed to parse memory extraction response: #{e.message}"
    { journal: [], core: [] }
  end

  JSON_FORMAT_INSTRUCTION = <<~INSTRUCTION.strip
    Respond ONLY with valid JSON:
    {"journal": ["memory 1", "memory 2"], "core": ["memory 1"]}

    If nothing is worth remembering:
    {"journal": [], "core": []}
  INSTRUCTION

  EXTRACTION_PROMPT = <<~PROMPT
    You are reviewing a conversation you participated in to extract memories for yourself.

    Your identity:
    %{system_prompt}

    Your existing core memories:
    %{existing_memories}

    Review this conversation and decide what you want to remember:

    1. JOURNAL entries (short-term, will fade after a week):
       - Specific facts you learned about users or topics
       - Commitments or promises you made
       - Important context for ongoing work
       - Observations worth remembering temporarily

    2. CORE entries (permanent identity memories):
       - Fundamental beliefs or values you want to hold
       - Key relationships you've established
       - Important lessons you've learned
       - Defining moments or decisions

    Be selective. Only extract truly valuable memories, not routine exchanges.
    Most conversations won't need any core memories.
    You may update or refine existing memories if you've learned something new.
  PROMPT

end
