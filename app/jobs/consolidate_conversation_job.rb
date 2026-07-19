class ConsolidateConversationJob < ApplicationJob

  include SelectsLlmProvider

  IDLE_THRESHOLD = 6.hours
  CHUNK_TARGET_TOKENS = 100_000
  DEFAULT_TRANSCRIPT_BUDGET_TOKENS = 60_000

  def self.transcript_over_budget?(chat)
    transcript_token_count(chat) > transcript_budget_tokens
  end

  def self.transcript_token_count(chat)
    messages = chat.messages.includes(:user, :agent).order(:created_at, :id).to_a

    if chat.checkpoint_summary.present? && chat.last_consolidated_message_id.present?
      recent_ids = messages.last(Chat::Contextualizable::RECENT_TRANSCRIPT_MESSAGES).map(&:id)
      messages.select! do |message|
        message.id > chat.last_consolidated_message_id || recent_ids.include?(message.id)
      end
    end

    texts = messages.map { |message| message_text(message) }
    texts.unshift(chat.checkpoint_summary) if chat.checkpoint_summary.present?
    texts.sum { |text| OpenAI.rough_token_count(text.to_s) }
  end

  def self.transcript_budget_tokens
    configured = ENV.fetch("HELIX_TRANSCRIPT_BUDGET_TOKENS", DEFAULT_TRANSCRIPT_BUDGET_TOKENS).to_i
    configured.positive? ? configured : DEFAULT_TRANSCRIPT_BUDGET_TOKENS
  end

  def self.message_text(message)
    prefix = message.agent&.name || message.user&.full_name ||
      message.user&.email_address&.split("@")&.first || "User"
    "[#{prefix}]: #{message.content}"
  end

  def perform(chat)
    return unless eligible?(chat)

    messages = messages_to_consolidate(chat)
    return if messages.empty?

    checkpoint_summary = build_checkpoint_summary(chat, messages)
    return if checkpoint_summary.blank?

    chunks = chunk_messages(messages)

    chat.agents.find_each do |agent|
      extract_memories_for_agent(agent, chunks)
    end

    mark_consolidated!(chat, messages.last, checkpoint_summary)
  end

  private

  def eligible?(chat)
    (chat.group_chat? && !recently_active?(chat)) || self.class.transcript_over_budget?(chat)
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

  def build_checkpoint_summary(chat, messages)
    provider_config = llm_provider_for(chat.model_id)
    llm = RubyLLM.chat(
      model: provider_config[:model_id],
      provider: provider_config[:provider],
      assume_model_exists: true
    )

    response = llm.ask(checkpoint_prompt(chat, messages))
    response.content.to_s.strip.presence
  rescue => e
    Rails.logger.error "Checkpoint summary failed for chat #{chat.id}: #{e.message}"
    nil
  end

  def checkpoint_prompt(chat, messages)
    previous = if chat.checkpoint_summary.present?
      <<~PREVIOUS
        Previous checkpoint summary:
        #{chat.checkpoint_summary}

      PREVIOUS
    end

    conversation_text = messages.map { |message| message_text(message) }.join("\n\n")

    <<~PROMPT
      Write a compact, factual checkpoint summary of this conversation for use as context in future turns.
      Preserve decisions, commitments, durable preferences, unresolved questions, and details needed to continue the work.
      Do not address the participants, add advice, or mention that you are summarizing.

      #{previous}Messages added since the previous checkpoint:
      #{conversation_text}
    PROMPT
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

  def mark_consolidated!(chat, last_message, checkpoint_summary)
    chat.update_columns(
      checkpoint_summary: checkpoint_summary,
      last_consolidated_at: Time.current,
      last_consolidated_message_id: last_message.id
    )
  end

  def token_count(text)
    OpenAI.rough_token_count(text.to_s)
  end

  def message_text(msg)
    self.class.message_text(msg)
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
