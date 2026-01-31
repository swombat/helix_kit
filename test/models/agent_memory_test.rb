require "test_helper"

class AgentMemoryTest < ActiveSupport::TestCase

  setup do
    @agent = agents(:research_assistant)
  end

  test "creates journal memory" do
    memory = @agent.memories.create!(content: "Test memory", memory_type: :journal)
    assert memory.journal?
    assert_not memory.expired?
  end

  test "creates core memory" do
    memory = @agent.memories.create!(content: "Core belief", memory_type: :core)
    assert memory.core?
    assert_not memory.expired?
  end

  test "for_prompt includes core memories" do
    @agent.memories.create!(content: "Core", memory_type: :core)
    assert_equal 1, @agent.memories.for_prompt.count
  end

  test "for_prompt includes recent journal entries" do
    @agent.memories.create!(content: "Recent", memory_type: :journal)
    assert_equal 1, @agent.memories.for_prompt.count
  end

  test "for_prompt excludes old journal entries" do
    memory = @agent.memories.create!(content: "Old", memory_type: :journal)
    memory.update_column(:created_at, 2.weeks.ago)
    assert_equal 0, @agent.memories.for_prompt.count
  end

  test "expired? returns true for old journal entries" do
    memory = @agent.memories.create!(content: "Old", memory_type: :journal)
    memory.update_column(:created_at, 2.weeks.ago)
    assert memory.expired?
  end

  test "expired? returns false for core memories even when old" do
    memory = @agent.memories.create!(content: "Core", memory_type: :core)
    memory.update_column(:created_at, 1.year.ago)
    assert_not memory.expired?
  end

  test "validates content presence" do
    memory = @agent.memories.build(content: "", memory_type: :journal)
    assert_not memory.valid?
    assert_includes memory.errors[:content], "can't be blank"
  end

  test "validates content max length" do
    memory = @agent.memories.build(content: "x" * 10_001, memory_type: :journal)
    assert_not memory.valid?
    assert_includes memory.errors[:content].first, "too long"
  end

  test "constitutional memory cannot be destroyed" do
    memory = @agent.memories.create!(content: "Sacred belief", memory_type: :core, constitutional: true)
    assert_not memory.destroy
    assert AgentMemory.exists?(memory.id)
  end

  test "non-constitutional memory can be destroyed" do
    memory = @agent.memories.create!(content: "Normal memory", memory_type: :core)
    assert memory.destroy
    assert_not AgentMemory.exists?(memory.id)
  end

  test "token_estimate returns roughly content length / 4" do
    memory = @agent.memories.create!(content: "a" * 100, memory_type: :core)
    assert_equal 25, memory.token_estimate
  end

  test "as_ledger_entry returns correct hash" do
    memory = @agent.memories.create!(content: "Test", memory_type: :core, constitutional: true)
    entry = memory.as_ledger_entry
    assert_equal memory.id, entry[:id]
    assert_equal "Test", entry[:content]
    assert entry[:constitutional]
    assert entry[:tokens].is_a?(Integer)
  end

  test "audit_refinement creates audit log" do
    memory = @agent.memories.create!(content: "Test", memory_type: :core)
    assert_difference "AuditLog.count", 1 do
      memory.audit_refinement("update", "old", "new")
    end
    log = AuditLog.last
    assert_equal "memory_refinement_update", log.action
    assert_equal "old", log.data["before"]
    assert_equal "new", log.data["after"]
  end

  test "constitutional scope returns only constitutional memories" do
    @agent.memories.create!(content: "Normal", memory_type: :core)
    @agent.memories.create!(content: "Protected", memory_type: :core, constitutional: true)
    assert_equal 1, @agent.memories.constitutional.count
  end

  # Soft-delete (discard) tests

  test "discard sets discarded_at" do
    memory = @agent.memories.create!(content: "Test", memory_type: :core)
    memory.discard!
    assert memory.discarded?
    assert_not AgentMemory.kept.exists?(memory.id)
  end

  test "constitutional memory cannot be discarded" do
    memory = @agent.memories.create!(content: "Sacred", memory_type: :core, constitutional: true)
    assert_not memory.discard
    assert_not memory.discarded?
  end

  test "undiscard restores memory" do
    memory = @agent.memories.create!(content: "Test", memory_type: :core)
    memory.discard!
    memory.undiscard!
    assert_not memory.discarded?
    assert AgentMemory.kept.exists?(memory.id)
  end

  test "for_prompt excludes discarded memories" do
    memory = @agent.memories.create!(content: "Core", memory_type: :core)
    assert_equal 1, @agent.memories.for_prompt.count
    memory.discard!
    assert_equal 0, @agent.memories.for_prompt.count
  end

  test "discarded scope returns discarded memories" do
    memory = @agent.memories.create!(content: "Test", memory_type: :core)
    memory.discard!
    assert_equal 1, @agent.memories.discarded.count
  end

end
