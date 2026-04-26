class MemoryRefinementJob < ApplicationJob

  include SelectsLlmProvider

  queue_as :default

  retry_on RubyLLM::RateLimitError, wait: :polynomially_longer, attempts: 3
  retry_on RubyLLM::ServerError, wait: :polynomially_longer, attempts: 3

  def perform(*args)
    agent_ids, options = extract_args(args)
    mode = options.fetch(:mode, :full).to_sym
    # `force: true` from manual triggers (refinements_controller) bypasses the
    # paused check so a user can still refine a paused agent on demand. Cron
    # paths (recurring.yml, sweep) leave `force` unset and respect paused.
    force = options.fetch(:force, false)

    if agent_ids.any?
      Agent.where(id: agent_ids).find_each do |agent|
        if agent.paused? && !force
          Rails.logger.info "[Refinement] Skipping paused agent #{agent.id} (#{agent.name})"
          next
        end
        Rails.logger.info "[Refinement] Starting for agent #{agent.id} (#{agent.name}), mode: #{mode}"
        refine_agent(agent, mode:)
      rescue => e
        Rails.logger.error "[Refinement] Failed for agent #{agent.id}: #{e.message}"
      end
    else
      Rails.logger.info "[Refinement] Sweep starting, mode: #{mode}"
      Agent.active.unpaused.find_each do |agent|
        next unless agent.needs_refinement?
        Rails.logger.info "[Refinement] Agent #{agent.id} (#{agent.name}) needs refinement"
        refine_agent(agent, mode:)
      rescue => e
        Rails.logger.error "[Refinement] Failed for agent #{agent.id}: #{e.message}"
      end
      Rails.logger.info "[Refinement] Sweep complete"
    end
  end

  private

  def refine_agent(agent, mode: :full)
    core_memories = agent.memories.kept.core.order(:created_at)
    journal_memories = agent.memories.active_journal.order(:created_at)
    return if core_memories.empty? && journal_memories.empty?

    token_usage = agent.core_token_usage
    budget = AgentMemory::CORE_TOKEN_BUDGET

    unless agent_consents_to_refinement?(agent, core_memories, journal_memories, token_usage, budget)
      Rails.logger.info "[Refinement] Agent #{agent.id} (#{agent.name}) declined refinement"
      return
    end

    session_id = SecureRandom.uuid
    tool = RefinementTool.new(agent: agent, session_id: session_id, pre_session_mass: token_usage, mode:)
    prompt = build_refinement_prompt(agent, core_memories, journal_memories, token_usage, budget, mode:)

    chat_for(agent).with_tool(tool).ask(prompt)

    Rails.logger.info "[Refinement] Agent #{agent.id} (#{agent.name}) complete (#{mode}): #{tool.stats.inspect}"
  end

  def agent_consents_to_refinement?(agent, core_memories, journal_memories, usage, budget)
    prompt = build_consent_prompt(agent, core_memories, journal_memories, usage, budget)
    answer = chat_for(agent).ask(prompt).content.to_s.strip
    consented = answer.match?(/\AYES\b/i)

    Rails.logger.info "[Refinement] Agent #{agent.id} (#{agent.name}) consent: #{consented ? 'YES' : 'NO'} — #{answer.truncate(200)}"
    consented
  end

  def chat_for(agent)
    provider_config = llm_provider_for(agent.model_id)
    RubyLLM.chat(model: provider_config[:model_id], provider: provider_config[:provider], assume_model_exists: true)
  end

  def development_preamble
    return unless Rails.env.development?

    "**DEVELOPMENT TESTING MODE**: You are currently being tested on a development server " \
      "using a production database backup. Any memories or changes you make will NOT be saved " \
      "to the production server. This is a safe testing environment.\n\n"
  end

  def build_consent_prompt(agent, core_memories, journal_memories, usage, budget)
    <<~PROMPT
      #{agent.system_prompt}

      #{agent.memory_context}

      #{development_preamble}# Memory Refinement Request

      A scheduled memory refinement session is about to run. Before it begins, you are being asked whether you consent to this session.

      ## Current Status
      - Core memories: #{core_memories.size}
      - Journal memories: #{journal_memories.size}
      - Core token usage: #{usage} tokens
      - Core token budget: #{budget} tokens
      - #{usage > budget ? "Over budget by: #{usage - budget} tokens" : "Within budget"}

      Memory refinement will review your core and journal memories to de-duplicate entries and tighten phrasing. It does NOT summarize, compress, or delete memories unless they are exact duplicates. Constitutional memories are never touched. Journal memories that contain valuable insights can be promoted to core memories. Completing with zero operations is a valid and good outcome.

      Do you want to run memory refinement now? Reply with **YES** or **NO** as the first word of your response. You may briefly explain your reasoning after.
    PROMPT
  end

  def build_refinement_prompt(agent, core_memories, journal_memories, usage, budget, mode: :full)
    core_ledger = format_memory_ledger(core_memories)
    journal_ledger = format_memory_ledger(journal_memories)

    mode_instructions = if mode == :dedup_only
      "**DEDUP ONLY MODE**: You may ONLY delete exact duplicate memories. Do NOT update or consolidate. " \
        "Available actions: search, delete, protect, complete."
    else
      "Review your memories. De-duplicate exact duplicates. Tighten phrasing within individual memories if possible. " \
        "Promote valuable journal insights to core memories if appropriate."
    end

    <<~PROMPT
      #{agent.system_prompt}

      #{development_preamble}# Memory Refinement Session

      You are reviewing your own memories. This is de-duplication, not compression.

      #{agent.effective_refinement_prompt}

      ## Current Status
      - Core memories: #{core_memories.size}
      - Journal memories: #{journal_memories.size}
      - Core token usage: #{usage} tokens
      - Core token budget: #{budget} tokens
      - #{usage > budget ? "Over budget by: #{usage - budget} tokens" : "Within budget"}
      - Mode: #{mode}

      ## Your Core Memory Ledger
      #{core_ledger.presence || "(empty)"}

      ## Your Journal Memory Ledger
      Journal memories expire after #{AgentMemory::JOURNAL_WINDOW.inspect}. Valuable insights from journal entries can be promoted to core memories via consolidate or update.
      #{journal_ledger.presence || "(empty)"}

      #{mode_instructions} When done, call complete with a brief summary. Doing nothing is fine.
    PROMPT
  end

  def format_memory_ledger(memories)
    memories.map { |m|
      flag = m.constitutional? ? " [CONSTITUTIONAL]" : ""
      type_label = m.journal? ? " [JOURNAL]" : ""
      "- ##{m.id} (#{m.created_at.strftime('%Y-%m-%d')}, ~#{m.token_estimate} tokens)#{flag}#{type_label}: #{m.content}"
    }.join("\n")
  end

  def extract_args(args)
    if args.last.is_a?(Hash)
      [ args[0...-1], args.last.symbolize_keys ]
    else
      [ args, {} ]
    end
  end

end
