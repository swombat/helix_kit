module Agent::Memory

  extend ActiveSupport::Concern

  DEFAULT_REFINEMENT_THRESHOLD = 0.90

  DEFAULT_SUMMARY_PROMPT = <<~PROMPT.freeze
    You are summarizing a conversation you are participating in. This summary is for
    your own reference so you can track what is happening across multiple conversations.

    Focus on the current STATE of the conversation:
    - What is being worked on right now?
    - What decisions are pending?
    - What has been agreed or resolved?

    Do NOT narrate what happened. Describe where things stand.

    Write exactly 2 lines. Be specific and concrete.
  PROMPT

  DEFAULT_REFINEMENT_PROMPT = <<~PROMPT.strip.freeze
    ## Refinement Guidelines
    - You may perform AT MOST 10 mutating operations (consolidate, update, delete) in this session. The system will refuse further operations after 10.
    - CONSTITUTIONAL memories cannot be deleted or consolidated.
    - Audio, somatic, and voice memories are immutable. Do not touch them.
    - Relational-specific memories (vows, quotes, specific dates, emotional texture) should only be touched if they are exact duplicates of another memory.
    - A memory is redundant ONLY if another memory already carries the same specific moment, quote, or insight. Near-duplicates with different emotional texture are NOT duplicates.
    - Completing with ZERO operations is a valid and good outcome.
    - When uncertain, do nothing. Bias toward completing with zero operations.
  PROMPT

  included do
    has_many :memories, class_name: "AgentMemory", dependent: :destroy

    const_set(:DEFAULT_REFINEMENT_THRESHOLD, DEFAULT_REFINEMENT_THRESHOLD) unless const_defined?(:DEFAULT_REFINEMENT_THRESHOLD, false)
    const_set(:DEFAULT_SUMMARY_PROMPT, DEFAULT_SUMMARY_PROMPT) unless const_defined?(:DEFAULT_SUMMARY_PROMPT, false)
    const_set(:DEFAULT_REFINEMENT_PROMPT, DEFAULT_REFINEMENT_PROMPT) unless const_defined?(:DEFAULT_REFINEMENT_PROMPT, false)
  end

  def effective_refinement_threshold
    refinement_threshold || DEFAULT_REFINEMENT_THRESHOLD
  end

  def effective_summary_prompt
    summary_prompt.presence || DEFAULT_SUMMARY_PROMPT
  end

  def effective_refinement_prompt
    refinement_prompt.presence || DEFAULT_REFINEMENT_PROMPT
  end

  def memory_context
    active = memories.for_prompt.to_a
    return nil if active.empty?

    [
      core_memory_section(active),
      journal_memory_section(active)
    ].compact.join("\n\n").then { |context| "# Your Private Memory\n\n#{context}" }
  end

  def memories_count
    raw = memories.kept.group(:memory_type).count
    { core: raw.fetch("core", 0), journal: raw.fetch("journal", 0) }
  end

  def memory_token_summary
    core_tokens = memories.kept.core.sum("CEIL(CHAR_LENGTH(content) / 4.0)").to_i
    active_journal_tokens = memories.active_journal.sum("CEIL(CHAR_LENGTH(content) / 4.0)").to_i
    inactive_journal_tokens = memories.kept.journal.where(created_at: ...AgentMemory::JOURNAL_WINDOW.ago).sum("CEIL(CHAR_LENGTH(content) / 4.0)").to_i
    { core: core_tokens, active_journal: active_journal_tokens, inactive_journal: inactive_journal_tokens }
  end

  def core_token_usage
    memories.kept.core.sum("CEIL(CHAR_LENGTH(content) / 4.0)").to_i
  end

  def needs_refinement?
    return true if last_refinement_at.nil? || last_refinement_at < 1.week.ago
    core_token_usage > AgentMemory::CORE_TOKEN_BUDGET
  end

  private

  def core_memory_section(memories)
    core = memories.select(&:core?)
    return unless core.any?

    "## Core Memories (permanent)\n" + core.map { |memory| "- #{memory.content}" }.join("\n")
  end

  def journal_memory_section(memories)
    journal = memories.select(&:journal?)
    return unless journal.any?

    "## Recent Journal Entries\n" + journal.map { |memory| "- [#{memory.created_at.strftime('%Y-%m-%d')}] #{memory.content}" }.join("\n")
  end

end
