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

end
