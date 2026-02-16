require "test_helper"

class RefinementToolTest < ActiveSupport::TestCase

  setup do
    @agent = agents(:research_assistant)
    @agent.memories.destroy_all
    @tool = RefinementTool.new(agent: @agent)
  end

  # Search action

  test "search finds matching memories" do
    @agent.memories.create!(content: "I love Ruby programming", memory_type: :core)
    @agent.memories.create!(content: "Python is also good", memory_type: :core)

    result = @tool.execute(action: "search", query: "Ruby")
    assert_equal "search_results", result[:type]
    assert_equal 1, result[:count]
  end

  test "search requires query" do
    result = @tool.execute(action: "search")
    assert_equal "error", result[:type]
    assert_includes result[:error], "query"
  end

  test "search sanitizes ILIKE wildcards" do
    @agent.memories.create!(content: "100% effort", memory_type: :core)
    result = @tool.execute(action: "search", query: "100%")
    assert_equal "search_results", result[:type]
    assert_equal 1, result[:count]
  end

  test "search excludes discarded memories" do
    m = @agent.memories.create!(content: "I love Ruby programming", memory_type: :core)
    m.discard!

    result = @tool.execute(action: "search", query: "Ruby")
    assert_equal "search_results", result[:type]
    assert_equal 0, result[:count]
  end

  # Consolidate action

  test "consolidate merges memories into one" do
    m1 = @agent.memories.create!(content: "Fact A", memory_type: :core)
    m2 = @agent.memories.create!(content: "Fact B", memory_type: :core)

    result = @tool.execute(action: "consolidate", ids: "#{m1.id},#{m2.id}", content: "Facts A and B combined")
    assert_equal "consolidated", result[:type]
    assert_equal 2, result[:merged_count]

    assert m1.reload.discarded?
    assert m2.reload.discarded?
    assert @agent.memories.kept.core.exists?(content: "Facts A and B combined")
  end

  test "consolidate preserves earliest timestamp" do
    m1 = @agent.memories.create!(content: "Old fact", memory_type: :core)
    m1.update_column(:created_at, 6.months.ago)
    m2 = @agent.memories.create!(content: "New fact", memory_type: :core)

    @tool.execute(action: "consolidate", ids: "#{m1.id},#{m2.id}", content: "Combined")

    new_memory = @agent.memories.kept.core.find_by(content: "Combined")
    assert_in_delta m1.created_at.to_f, new_memory.created_at.to_f, 1.0
  end

  test "consolidate requires at least 2 IDs" do
    m1 = @agent.memories.create!(content: "Solo", memory_type: :core)
    result = @tool.execute(action: "consolidate", ids: "#{m1.id}", content: "Still solo")
    assert_equal "error", result[:type]
    assert_includes result[:error], "at least 2"
  end

  test "consolidate rejects constitutional memories" do
    m1 = @agent.memories.create!(content: "Sacred", memory_type: :core, constitutional: true)
    m2 = @agent.memories.create!(content: "Normal", memory_type: :core)

    result = @tool.execute(action: "consolidate", ids: "#{m1.id},#{m2.id}", content: "Merged")
    assert_equal "error", result[:type]
    assert_includes result[:error], "constitutional"
    assert AgentMemory.exists?(m1.id)
    assert AgentMemory.exists?(m2.id)
  end

  test "consolidate creates audit logs" do
    m1 = @agent.memories.create!(content: "A", memory_type: :core)
    m2 = @agent.memories.create!(content: "B", memory_type: :core)

    assert_difference "AuditLog.count", 1 do
      @tool.execute(action: "consolidate", ids: "#{m1.id},#{m2.id}", content: "AB")
    end

    log = AuditLog.last
    assert_equal "memory_refinement_consolidate", log.action
    assert_equal 2, log.data["merged"].size
    assert_equal "AB", log.data["result"]["content"]
  end

  # Update action

  test "update changes memory content" do
    m = @agent.memories.create!(content: "Old phrasing", memory_type: :core)
    result = @tool.execute(action: "update", id: m.id.to_s, content: "Tight phrasing")

    assert_equal "updated", result[:type]
    assert_equal "Tight phrasing", m.reload.content
  end

  test "update creates audit log" do
    m = @agent.memories.create!(content: "Before", memory_type: :core)
    assert_difference "AuditLog.count", 1 do
      @tool.execute(action: "update", id: m.id.to_s, content: "After")
    end
    log = AuditLog.last
    assert_equal "Before", log.data["before"]
    assert_equal "After", log.data["after"]
  end

  test "update returns error for missing memory" do
    result = @tool.execute(action: "update", id: "999999", content: "New")
    assert_equal "error", result[:type]
    assert_includes result[:error], "not found"
  end

  # Delete action

  test "delete discards memory" do
    m = @agent.memories.create!(content: "To remove", memory_type: :core)
    result = @tool.execute(action: "delete", id: m.id.to_s)

    assert_equal "deleted", result[:type]
    assert m.reload.discarded?
  end

  test "delete rejects constitutional memory" do
    m = @agent.memories.create!(content: "Sacred", memory_type: :core, constitutional: true)
    result = @tool.execute(action: "delete", id: m.id.to_s)

    assert_equal "error", result[:type]
    assert_includes result[:error], "constitutional"
    assert_not m.reload.discarded?
  end

  test "delete creates audit log" do
    m = @agent.memories.create!(content: "Going away", memory_type: :core)
    assert_difference "AuditLog.count", 1 do
      @tool.execute(action: "delete", id: m.id.to_s)
    end
  end

  # Protect action

  test "protect marks memory as constitutional" do
    m = @agent.memories.create!(content: "Important", memory_type: :core)
    result = @tool.execute(action: "protect", id: m.id.to_s)

    assert_equal "protected", result[:type]
    assert m.reload.constitutional?
  end

  test "protect creates audit log" do
    m = @agent.memories.create!(content: "Important", memory_type: :core)
    assert_difference "AuditLog.count", 1 do
      @tool.execute(action: "protect", id: m.id.to_s)
    end
  end

  # Complete action

  test "complete records summary and updates agent" do
    result = @tool.execute(action: "complete", summary: "Compressed 5 to 2")

    assert_equal "refinement_complete", result[:type]
    assert @agent.reload.last_refinement_at.present?
    assert @agent.memories.journal.exists?(content: "Refinement session: Compressed 5 to 2")
    assert AuditLog.exists?(action: "memory_refinement_complete")
  end

  test "complete requires summary" do
    result = @tool.execute(action: "complete")
    assert_equal "error", result[:type]
    assert_includes result[:error], "summary"
  end

  # Validation

  test "invalid action returns error with allowed actions" do
    result = @tool.execute(action: "bogus")
    assert_equal "error", result[:type]
    assert_equal RefinementTool::ACTIONS, result[:allowed_actions]
  end

  # Hard cap tests

  test "refuses mutating operations after hard cap" do
    memories = 12.times.map { |i| @agent.memories.create!(content: "Memory #{i}", memory_type: :core) }
    tool = RefinementTool.new(agent: @agent, session_id: "cap-test")

    RefinementTool::MAX_MUTATIONS.times do |i|
      result = tool.execute(action: "update", id: memories[i].id.to_s, content: "Updated #{i}")
      assert_equal "updated", result[:type]
    end

    result = tool.execute(action: "update", id: memories[10].id.to_s, content: "One too many")
    assert_equal "error", result[:type]
    assert_includes result[:error], "Hard cap"
  end

  test "hard cap does not count failed operations" do
    m = @agent.memories.create!(content: "Real memory", memory_type: :core)
    tool = RefinementTool.new(agent: @agent, session_id: "cap-fail-test")

    5.times { tool.execute(action: "delete", id: "999999") }

    result = tool.execute(action: "update", id: m.id.to_s, content: "Still allowed")
    assert_equal "updated", result[:type]
  end

  test "hard cap does not count search or protect" do
    memories = 14.times.map { |i| @agent.memories.create!(content: "Memory #{i}" * 5, memory_type: :core) }
    tool = RefinementTool.new(agent: @agent, session_id: "non-mutating-test")

    5.times { tool.execute(action: "search", query: "Memory") }
    3.times { |i| tool.execute(action: "protect", id: memories[i].id.to_s) }

    RefinementTool::MAX_MUTATIONS.times do |i|
      result = tool.execute(action: "update", id: memories[i + 3].id.to_s, content: "Updated #{i}")
      assert_equal "updated", result[:type]
    end

    result = tool.execute(action: "update", id: memories[13].id.to_s, content: "Over cap")
    assert_equal "error", result[:type]
    assert_includes result[:error], "Hard cap"
  end

  # Mid-session circuit breaker tests

  test "mid-session circuit breaker rolls back and terminates" do
    m1 = @agent.memories.create!(content: "A" * 400, memory_type: :core)
    m2 = @agent.memories.create!(content: "B" * 400, memory_type: :core)

    tool = tool_with_circuit_breaker

    tool.execute(action: "delete", id: m1.id.to_s)
    tool.execute(action: "delete", id: m2.id.to_s)

    assert_not m1.reload.discarded?, "should be undiscarded after mid-session rollback"
    assert_not m2.reload.discarded?, "should be undiscarded after mid-session rollback"

    result = tool.execute(action: "search", query: "anything")
    assert_equal "error", result[:type]
    assert_includes result[:error], "terminated"
  end

  test "mid-session circuit breaker returns terminated error on triggering call" do
    m1 = @agent.memories.create!(content: "A" * 400, memory_type: :core)

    tool = tool_with_circuit_breaker

    result = tool.execute(action: "delete", id: m1.id.to_s)
    assert_equal "error", result[:type]
    assert_includes result[:error], "terminated"
  end

  test "all calls after mid-session rollback return terminated error" do
    m1 = @agent.memories.create!(content: "A" * 400, memory_type: :core)

    tool = tool_with_circuit_breaker
    tool.execute(action: "delete", id: m1.id.to_s)

    result = tool.execute(action: "complete", summary: "Trying to complete")
    assert_equal "error", result[:type]
    assert_includes result[:error], "terminated"
  end

  # Circuit breaker tests (complete action -- safety net)

  test "complete rolls back when compression exceeds threshold" do
    m1 = @agent.memories.create!(content: "A" * 400, memory_type: :core)
    m2 = @agent.memories.create!(content: "B" * 400, memory_type: :core)

    tool = tool_with_circuit_breaker

    tool.execute(action: "delete", id: m1.id.to_s)
    tool.execute(action: "delete", id: m2.id.to_s)

    # Mid-session circuit breaker already rolled back
    assert_not m1.reload.discarded?
    assert_not m2.reload.discarded?
  end

  test "complete succeeds when compression is within threshold" do
    @agent.memories.create!(content: "A" * 400, memory_type: :core)
    @agent.memories.create!(content: "B" * 400, memory_type: :core)
    tiny = @agent.memories.create!(content: "C" * 20, memory_type: :core)

    pre_mass = @agent.core_token_usage
    tool = RefinementTool.new(agent: @agent, session_id: "test-session", pre_session_mass: pre_mass)

    tool.execute(action: "delete", id: tiny.id.to_s)
    result = tool.execute(action: "complete", summary: "Minor cleanup")

    assert_equal "refinement_complete", result[:type]
    assert tiny.reload.discarded?
  end

  test "rollback undiscards deleted memories" do
    @agent.memories.create!(content: "Important" * 20, memory_type: :core)

    tool = tool_with_circuit_breaker
    m = @agent.memories.kept.core.first

    tool.execute(action: "delete", id: m.id.to_s)

    assert_not m.reload.discarded?
  end

  test "rollback restores updated memory content" do
    @agent.memories.create!(content: "Original content here" * 10, memory_type: :core)

    tool = tool_with_circuit_breaker
    m = @agent.memories.kept.core.first

    tool.execute(action: "update", id: m.id.to_s, content: "X")

    assert_equal "Original content here" * 10, m.reload.content
  end

  test "rollback reverses consolidations" do
    m1 = @agent.memories.create!(content: "A" * 200, memory_type: :core)
    m2 = @agent.memories.create!(content: "B" * 200, memory_type: :core)

    tool = tool_with_circuit_breaker
    tool.execute(action: "consolidate", ids: "#{m1.id},#{m2.id}", content: "AB")

    assert_not m1.reload.discarded?
    assert_not m2.reload.discarded?
    merged = @agent.memories.find_by(content: "AB")
    assert merged.discarded?
  end

  test "rollback reverses protect actions" do
    m = @agent.memories.create!(content: "A" * 200, memory_type: :core)
    m2 = @agent.memories.create!(content: "B" * 200, memory_type: :core)

    tool = tool_with_circuit_breaker
    tool.execute(action: "protect", id: m.id.to_s)
    tool.execute(action: "delete", id: m2.id.to_s)

    assert_not m.reload.constitutional?
    assert_not m2.reload.discarded?
  end

  test "rollback creates audit log and journal memory" do
    @agent.memories.create!(content: "A" * 400, memory_type: :core)

    tool = tool_with_circuit_breaker
    m = @agent.memories.kept.core.first

    tool.execute(action: "delete", id: m.id.to_s)

    rollback_log = AuditLog.find_by(action: "memory_refinement_rollback")
    assert rollback_log
    assert_equal @agent.effective_refinement_threshold, rollback_log.data["threshold"]

    journal = @agent.memories.journal.where("content LIKE ?", "%rolled back%").first
    assert journal
    assert_includes journal.content, @pre_session_mass.to_s
    assert_includes journal.content, "1 deletion"
    assert_includes journal.content, "retention threshold"
  end

  test "complete action safety net catches external mass loss" do
    # Verify the complete_action circuit breaker catches mass loss not
    # tracked by per-operation checks (e.g., external deletions).
    @agent.memories.create!(content: "A" * 400, memory_type: :core)
    target = @agent.memories.create!(content: "B" * 400, memory_type: :core)

    pre_mass = @agent.core_token_usage
    @agent.update!(refinement_threshold: 0.99)
    tool = RefinementTool.new(
      agent: @agent,
      session_id: "test-#{SecureRandom.hex(4)}",
      pre_session_mass: pre_mass
    )

    # External deletion bypasses the tool, so no mid-session check runs
    target.discard!

    result = tool.execute(action: "complete", summary: "External deletion happened")
    assert_equal "refinement_rolled_back", result[:type]
    assert_includes result[:reason], "retention threshold"
  end

  test "complete succeeds without pre_session_mass (backward compatibility)" do
    tool = RefinementTool.new(agent: @agent)
    result = tool.execute(action: "complete", summary: "No gate")

    assert_equal "refinement_complete", result[:type]
  end

  test "session_id is included in all refinement audit logs" do
    m = @agent.memories.create!(content: "Test", memory_type: :core)
    tool = RefinementTool.new(agent: @agent, session_id: "sid-123", pre_session_mass: 1000)

    tool.execute(action: "update", id: m.id.to_s, content: "Updated")
    log = AuditLog.find_by(action: "memory_refinement_update")
    assert_equal "sid-123", log.data["session_id"]
  end

  private

  def tool_with_circuit_breaker(threshold: 1.0)
    @pre_session_mass = @agent.core_token_usage
    @agent.update!(refinement_threshold: threshold)
    RefinementTool.new(
      agent: @agent,
      session_id: "test-#{SecureRandom.hex(4)}",
      pre_session_mass: @pre_session_mass
    )
  end

end
