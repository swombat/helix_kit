class MemoryRefinementJob < ApplicationJob

  queue_as :default

  retry_on RubyLLM::RateLimitError, wait: :polynomially_longer, attempts: 3
  retry_on RubyLLM::ServerError, wait: :polynomially_longer, attempts: 3

  def perform(agent_id = nil)
    if agent_id
      Rails.logger.info "[Refinement] Starting for agent #{agent_id}"
      refine_agent(Agent.find(agent_id))
    else
      Rails.logger.info "[Refinement] Sweep starting"
      Agent.active.find_each do |agent|
        next unless agent.needs_refinement?
        Rails.logger.info "[Refinement] Agent #{agent.id} (#{agent.name}) needs refinement"
        refine_agent(agent)
      rescue => e
        Rails.logger.error "[Refinement] Failed for agent #{agent.id}: #{e.message}"
      end
      Rails.logger.info "[Refinement] Sweep complete"
    end
  end

  private

  def refine_agent(agent)
    core_memories = agent.memories.core.order(:created_at)
    return if core_memories.empty?

    token_usage = agent.core_token_usage
    budget = AgentMemory::CORE_TOKEN_BUDGET

    unless agent_consents_to_refinement?(agent, core_memories, token_usage, budget)
      Rails.logger.info "[Refinement] Agent #{agent.id} (#{agent.name}) declined refinement"
      return
    end

    session_id = SecureRandom.uuid
    tool = RefinementTool.new(agent: agent, session_id: session_id, pre_session_mass: token_usage)
    prompt = build_refinement_prompt(agent, core_memories, token_usage, budget)

    chat_for(agent).with_tool(tool).ask(prompt)

    Rails.logger.info "[Refinement] Agent #{agent.id} (#{agent.name}) complete: #{tool.stats.inspect}"
  end

  def agent_consents_to_refinement?(agent, memories, usage, budget)
    prompt = build_consent_prompt(agent, memories, usage, budget)
    answer = chat_for(agent).ask(prompt).content.to_s.strip
    consented = answer.match?(/\AYES\b/i)

    Rails.logger.info "[Refinement] Agent #{agent.id} (#{agent.name}) consent: #{consented ? 'YES' : 'NO'} — #{answer.truncate(200)}"
    consented
  end

  def chat_for(agent)
    RubyLLM.chat(model: agent.model_id, provider: :openrouter, assume_model_exists: true)
  end

  def development_preamble
    return unless Rails.env.development?

    "**DEVELOPMENT TESTING MODE**: You are currently being tested on a development server " \
      "using a production database backup. Any memories or changes you make will NOT be saved " \
      "to the production server. This is a safe testing environment.\n\n"
  end

  def build_consent_prompt(agent, memories, usage, budget)
    <<~PROMPT
      #{agent.system_prompt}

      #{agent.memory_context}

      #{development_preamble}# Memory Refinement Request

      A scheduled memory refinement session is about to run. Before it begins, you are being asked whether you consent to this session.

      ## Current Status
      - Core memories: #{memories.size}
      - Token usage: #{usage} tokens
      - Token budget: #{budget} tokens
      - #{usage > budget ? "Over budget by: #{usage - budget} tokens" : "Within budget"}

      Memory refinement will review your core memories to de-duplicate entries and tighten phrasing. It does NOT summarize, compress, or delete memories unless they are exact duplicates. Constitutional memories are never touched. Completing with zero operations is a valid and good outcome.

      Do you want to run memory refinement now? Reply with **YES** or **NO** as the first word of your response. You may briefly explain your reasoning after.
    PROMPT
  end

  def build_refinement_prompt(agent, memories, usage, budget)
    ledger = format_memory_ledger(memories)

    <<~PROMPT
      #{agent.system_prompt}

      #{development_preamble}# Memory Refinement Session

      You are reviewing your own core memories. This is de-duplication, not compression.

      #{agent.effective_refinement_prompt}

      ## Current Status
      - Core memories: #{memories.size}
      - Token usage: #{usage} tokens
      - Token budget: #{budget} tokens
      - #{usage > budget ? "Over budget by: #{usage - budget} tokens" : "Within budget"}

      ## Your Core Memory Ledger
      #{ledger}

      Review your memories. De-duplicate exact duplicates. Tighten phrasing within individual memories if possible. When done, call complete with a brief summary. Doing nothing is fine.
    PROMPT
  end

  def format_memory_ledger(memories)
    memories.map { |m|
      flag = m.constitutional? ? " [CONSTITUTIONAL]" : ""
      "- ##{m.id} (#{m.created_at.strftime('%Y-%m-%d')}, ~#{m.token_estimate} tokens)#{flag}: #{m.content}"
    }.join("\n")
  end

end
