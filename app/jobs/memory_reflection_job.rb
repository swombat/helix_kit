class MemoryReflectionJob < ApplicationJob

  queue_as :default

  retry_on RubyLLM::RateLimitError, wait: :polynomially_longer, attempts: 5
  retry_on RubyLLM::ServerError, wait: :polynomially_longer, attempts: 3
  retry_on Faraday::Error, wait: :polynomially_longer, attempts: 3

  def perform
    agents_with_recent_journal.find_each do |agent|
      reflect_for_agent(agent)
    rescue => e
      Rails.logger.error "Memory reflection failed for agent #{agent.id}: #{e.message}"
      # Continue with other agents
    end
  end

  private

  def agents_with_recent_journal
    Agent.joins(:memories)
         .merge(AgentMemory.active_journal)
         .distinct
  end

  def reflect_for_agent(agent)
    core_memories = agent.memories.core.pluck(:content)
    journal_entries = agent.memories.active_journal.order(:created_at)

    return if journal_entries.empty?

    prompt = format(REFLECTION_PROMPT,
      core_memories: format_core_memories(core_memories),
      journal_entries: format_journal_entries(journal_entries)
    )

    llm = RubyLLM.chat(
      model: agent.model_id,
      provider: :openrouter,
      assume_model_exists: true
    )

    response = llm.ask(prompt)
    indices_to_promote = parse_response(response)

    promote_memories(journal_entries, indices_to_promote)
  end

  def format_core_memories(memories)
    return "None yet - you're still forming your identity." if memories.empty?
    memories.map.with_index(1) { |m, i| "#{i}. #{m}" }.join("\n")
  end

  def format_journal_entries(entries)
    entries.map.with_index(1) do |memory, i|
      "#{i}. [#{memory.created_at.strftime('%Y-%m-%d')}] #{memory.content}"
    end.join("\n")
  end

  def parse_response(response)
    json = JSON.parse(response.content)
    Array(json["promote"]).map(&:to_i).reject(&:zero?)
  rescue JSON::ParserError => e
    Rails.logger.warn "Failed to parse reflection response: #{e.message}"
    []
  end

  def promote_memories(journal_entries, indices)
    entries_array = journal_entries.to_a

    promoted_count = 0
    indices.each do |index|
      memory = entries_array[index - 1] # Convert 1-based to 0-based
      next unless memory

      memory.update!(memory_type: :core)
      promoted_count += 1
    end

    if promoted_count > 0
      Rails.logger.info "Agent #{entries_array.first.agent_id} promoted #{promoted_count} journal entries to core memories"
    end
  end

  REFLECTION_PROMPT = <<~PROMPT
    You are reflecting on your recent experiences and observations.

    Below are your permanent core memories (your identity and key learnings) followed by
    your recent journal entries (numbered, temporary observations from the past week).

    Review your journal entries and decide which, if any, should be promoted to permanent
    core memories. Consider:

    - Does this represent a lasting insight about yourself, users, or your role?
    - Is this a pattern you've observed that will remain relevant?
    - Does this capture something fundamental about how you should operate?
    - Would losing this memory make you less effective long-term?

    Most journal entries should NOT become core memories - they're meant to fade.
    Only promote entries that represent genuine, lasting insights. It is completely
    normal and expected to promote nothing.

    ## Your Core Memories (permanent)
    %{core_memories}

    ## Recent Journal Entries (will fade after 1 week)
    %{journal_entries}

    ---

    Respond ONLY with valid JSON. List the numbers of journal entries to promote:

    {"promote": [1, 3]}

    If nothing should be promoted (most common case):
    {"promote": []}
  PROMPT

end
