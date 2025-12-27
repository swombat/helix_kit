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

end
