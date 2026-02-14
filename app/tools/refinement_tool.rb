class RefinementTool < RubyLLM::Tool

  ACTIONS = %w[search consolidate update delete protect complete].freeze

  description "Memory refinement tool. Actions: search, consolidate, update, delete, protect, complete."

  param :action, type: :string,
        desc: "search, consolidate, update, delete, protect, or complete",
        required: true

  param :query, type: :string,
        desc: "Search query (for search action)",
        required: false

  param :ids, type: :string,
        desc: "Comma-separated memory IDs (for consolidate)",
        required: false

  param :id, type: :string,
        desc: "Single memory ID (for update, delete, protect)",
        required: false

  param :content, type: :string,
        desc: "New content (for consolidate, update)",
        required: false

  param :summary, type: :string,
        desc: "Refinement summary (for complete)",
        required: false

  attr_reader :stats

  def initialize(agent:, session_id: nil, pre_session_mass: nil)
    super()
    @agent = agent
    @session_id = session_id
    @pre_session_mass = pre_session_mass
    @stats = { consolidated: 0, updated: 0, deleted: 0, protected: 0 }
  end

  def execute(action:, **params)
    Rails.logger.info "[Refinement] Agent #{@agent.id}: #{action}"
    return validation_error("Invalid action '#{action}'") unless ACTIONS.include?(action)
    send("#{action}_action", **params)
  end

  private

  def search_action(query: nil, **)
    return param_error("search", "query") if query.blank?

    results = @agent.memories.kept.core
                    .where("content ILIKE ?", "%#{AgentMemory.sanitize_sql_like(query)}%")
                    .order(:created_at)
                    .map(&:as_ledger_entry)

    { type: "search_results", query:, count: results.size, results: }
  end

  def consolidate_action(ids: nil, content: nil, **)
    return param_error("consolidate", "ids") if ids.blank?
    return param_error("consolidate", "content") if content.blank?

    memory_ids = ids.split(",").map(&:strip).map(&:to_i)
    return { type: "error", error: "consolidate requires at least 2 memory IDs" } if memory_ids.size < 2

    memories = @agent.memories.kept.core.where(id: memory_ids)
    return { type: "error", error: "No matching memories found" } if memories.empty?

    constitutional = memories.select(&:constitutional?)
    if constitutional.any?
      return { type: "error", error: "Cannot consolidate constitutional memories: #{constitutional.map(&:id).join(', ')}" }
    end

    earliest = memories.map(&:created_at).min

    ActiveRecord::Base.transaction do
      new_memory = @agent.memories.create!(content: content.strip, memory_type: :core, created_at: earliest)

      merged = memories.map { |m| { id: m.id, content: m.content } }
      memories.each(&:discard!)

      AuditLog.create!(
        action: "memory_refinement_consolidate",
        auditable: new_memory,
        account_id: @agent.account_id,
        data: {
          agent_id: @agent.id,
          session_id: @session_id,
          operation: "consolidate",
          merged: merged,
          result: { id: new_memory.id, content: new_memory.content }
        }
      )

      @stats[:consolidated] += memories.size
    end

    { type: "consolidated", merged_count: memory_ids.size, new_content: content }
  end

  def update_action(id: nil, content: nil, **)
    return param_error("update", "id") if id.blank?
    return param_error("update", "content") if content.blank?

    memory = @agent.memories.kept.core.find_by(id: id)
    return { type: "error", error: "Memory ##{id} not found" } unless memory

    old_content = memory.content
    memory.update!(content: content.strip)
    memory.audit_refinement("update", old_content, memory.content, session_id: @session_id)
    @stats[:updated] += 1

    { type: "updated", id: memory.id, content: memory.content }
  end

  def delete_action(id: nil, **)
    return param_error("delete", "id") if id.blank?

    memory = @agent.memories.kept.core.find_by(id: id)
    return { type: "error", error: "Memory ##{id} not found" } unless memory
    return { type: "error", error: "Cannot delete constitutional memory ##{id}" } if memory.constitutional?

    memory.audit_refinement("delete", memory.content, nil, session_id: @session_id)
    memory.discard!
    @stats[:deleted] += 1

    { type: "deleted", id: memory.id }
  end

  def protect_action(id: nil, **)
    return param_error("protect", "id") if id.blank?

    memory = @agent.memories.kept.core.find_by(id: id)
    return { type: "error", error: "Memory ##{id} not found" } unless memory

    memory.update!(constitutional: true)
    memory.audit_refinement("protect", nil, nil, session_id: @session_id)
    @stats[:protected] += 1

    { type: "protected", id: memory.id, content: memory.content }
  end

  def complete_action(summary: nil, **)
    return param_error("complete", "summary") if summary.blank?

    if circuit_breaker_tripped?
      rollback_session!
      return {
        type: "refinement_rolled_back",
        summary: summary,
        stats: @stats,
        reason: "Session exceeded maximum allowed compression " \
                "(#{(@agent.effective_refinement_threshold * 100).to_i}% retention threshold)"
      }
    end

    AuditLog.create!(
      action: "memory_refinement_complete",
      auditable: @agent,
      account_id: @agent.account_id,
      data: { session_id: @session_id, summary: summary, stats: @stats }
    )

    @agent.memories.create!(content: "Refinement session: #{summary}", memory_type: :journal)
    @agent.update!(last_refinement_at: Time.current)

    { type: "refinement_complete", summary: summary, stats: @stats }
  end

  def circuit_breaker_tripped?
    return false unless @pre_session_mass && @pre_session_mass > 0

    new_mass = @agent.core_token_usage
    ratio = new_mass.to_f / @pre_session_mass
    ratio < @agent.effective_refinement_threshold
  end

  def rollback_session!
    post_compression_mass = @agent.core_token_usage
    ActiveRecord::Base.transaction do
      reverse_session_mutations!
      record_rollback_audit!(post_compression_mass)
      record_rollback_journal!(post_compression_mass)
      @agent.update!(last_refinement_at: Time.current)
    end
  end

  def reverse_session_mutations!
    session_audit_logs.each { |log| reverse_mutation(log) }
  end

  def reverse_mutation(log)
    case log.action
    when "memory_refinement_delete"
      AgentMemory.with_discarded.find_by(id: log.auditable_id)&.undiscard!
    when "memory_refinement_update"
      memory = AgentMemory.find_by(id: log.auditable_id)
      memory&.update!(content: log.data["before"]) if log.data["before"]
    when "memory_refinement_consolidate"
      reverse_consolidation(log)
    when "memory_refinement_protect"
      # Entire session is rolled back -- revert constitutional flags granted during this session
      AgentMemory.find_by(id: log.auditable_id)&.update!(constitutional: false)
    end
  end

  def reverse_consolidation(log)
    AgentMemory.find_by(id: log.data.dig("result", "id"))&.discard!
    log.data["merged"]&.each do |original|
      AgentMemory.with_discarded.find_by(id: original["id"])&.undiscard!
    end
  end

  def record_rollback_audit!(post_compression_mass)
    AuditLog.create!(
      action: "memory_refinement_rollback",
      auditable: @agent,
      account_id: @agent.account_id,
      data: {
        session_id: @session_id,
        pre_session_mass: @pre_session_mass,
        post_session_mass: post_compression_mass,
        threshold: @agent.effective_refinement_threshold,
        stats: @stats
      }
    )
  end

  def record_rollback_journal!(post_compression_mass)
    reduction_pct = (100 - (post_compression_mass.to_f / @pre_session_mass * 100)).round(1)
    threshold_pct = (@agent.effective_refinement_threshold * 100).to_i

    stat_labels = { deleted: "deletion", consolidated: "consolidation", updated: "update", protected: "protection" }
    parts = stat_labels.filter_map { |key, word| "#{@stats[key]} #{word.pluralize(@stats[key])}" if @stats[key] > 0 }
    stats_summary = parts.any? ? "Rolled back: #{parts.join(', ')}." : ""

    @agent.memories.create!(
      content: "Refinement session rolled back. Would have reduced core memory from " \
               "#{@pre_session_mass} to #{post_compression_mass} tokens (#{reduction_pct}% cut), " \
               "exceeding the #{threshold_pct}% retention threshold. #{stats_summary} " \
               "All changes reversed to protect memory integrity.",
      memory_type: :journal
    )
  end

  def session_audit_logs
    AuditLog.for_refinement_session(@session_id).order(created_at: :desc)
  end

  def validation_error(message)
    { type: "error", error: message, allowed_actions: ACTIONS }
  end

  def param_error(action, param)
    { type: "error", error: "#{param} is required for #{action}" }
  end

end
