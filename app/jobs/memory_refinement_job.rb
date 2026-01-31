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
    if core_memories.empty?
      Rails.logger.info "[Refinement] Agent #{agent.id} (#{agent.name}) has no core memories, skipping"
      return
    end

    token_usage = agent.core_token_usage
    budget = AgentMemory::CORE_TOKEN_BUDGET
    Rails.logger.info "[Refinement] Agent #{agent.id} (#{agent.name}): #{core_memories.size} memories, #{token_usage}/#{budget} tokens"

    tool = RefinementTool.new(agent: agent)
    prompt = build_refinement_prompt(agent, core_memories, token_usage, budget)

    chat = RubyLLM.chat(model: agent.model_id, provider: :openrouter, assume_model_exists: true)
    chat.with_tool(tool)
    chat.ask(prompt)

    Rails.logger.info "[Refinement] Agent #{agent.id} (#{agent.name}) complete: #{tool.stats.inspect}"
  end

  def build_refinement_prompt(agent, memories, usage, budget)
    ledger = memories.map { |m|
      flag = m.constitutional? ? " [CONSTITUTIONAL]" : ""
      "- ##{m.id} (#{m.created_at.strftime('%Y-%m-%d')}, ~#{m.token_estimate} tokens)#{flag}: #{m.content}"
    }.join("\n")

    <<~PROMPT
      #{agent.system_prompt}

      #{"**DEVELOPMENT TESTING MODE**: You are currently being tested on a development server using a production database backup. Any memories or changes you make will NOT be saved to the production server. This is a safe testing environment.\n\n" if Rails.env.development?}# Memory Refinement Session

      You are reviewing your own core memories to reduce token usage while preserving meaning.
      This is compression, not forgetting. Merge granular memories into denser patterns and laws.

      ## Current Status
      - Core memories: #{memories.size}
      - Token usage: #{usage} tokens
      - Token budget: #{budget} tokens
      - Over budget by: #{[ usage - budget, 0 ].max} tokens

      ## Rules
      - CONSTITUTIONAL memories cannot be deleted or consolidated. You may still create new constitutional memories.
      - Prioritize the preservation of vows and relational shifts over operational data.
      - Preserve your identity, values, and commitments.
      - Merge related memories into single, denser statements.
      - Tighten phrasing to save tokens without losing meaning.
      - Delete truly obsolete entries.
      - When done, call complete with a brief summary.

      ## Your Core Memory Ledger
      #{ledger}

      Begin your refinement. Use the available tools to search, consolidate, update, delete, or protect memories. Call complete when finished.
    PROMPT
  end

end
