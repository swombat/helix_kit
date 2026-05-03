require "test_helper"

class MemoryReflectionJobTest < ActiveSupport::TestCase

  setup do
    @agent = agents(:research_assistant)
    @agent.memories.destroy_all
    @agent.update!(
      model_id: "openai/gpt-5-nano",
      memory_reflection_prompt: nil
    )

    @journal1 = @agent.memories.create!(content: "User prefers concise answers", memory_type: :journal)
    @journal2 = @agent.memories.create!(content: "Discussed project deadline of Jan 15", memory_type: :journal)
    @journal3 = @agent.memories.create!(content: "I work best when I ask clarifying questions", memory_type: :journal)
  end

  test "skips agents without recent journal entries" do
    @agent.memories.journal.destroy_all

    MemoryReflectionJob.perform_now

    assert_equal 0, @agent.memories.core.count
  end

  test "skips agents with only expired journal entries" do
    @agent.memories.journal.update_all(created_at: 2.weeks.ago)

    MemoryReflectionJob.perform_now

    assert_equal 0, @agent.memories.core.count
  end

  test "promotes selected journal entries through RubyLLM" do
    @agent.update!(
      memory_reflection_prompt: <<~PROMPT
        You are testing memory promotion.
        Always promote journal entries 1 and 3, and do not promote entry 2.

        Core memories:
        %{core_memories}

        Journal entries:
        %{journal_entries}
      PROMPT
    )

    VCR.use_cassette("jobs/memory_reflection_job/promotes_selected_entries") do
      MemoryReflectionJob.perform_now
    end

    assert_predicate @journal1.reload, :core?
    assert_predicate @journal2.reload, :journal?
    assert_predicate @journal3.reload, :core?
    assert_equal 3, @agent.memories.count
  end

  test "handles empty promotion list through RubyLLM" do
    @agent.update!(
      memory_reflection_prompt: <<~PROMPT
        You are testing memory promotion.
        Always respond that no journal entries should be promoted.

        Core memories:
        %{core_memories}

        Journal entries:
        %{journal_entries}
      PROMPT
    )

    VCR.use_cassette("jobs/memory_reflection_job/promotes_nothing") do
      MemoryReflectionJob.perform_now
    end

    assert_equal 0, @agent.memories.core.count
    assert_equal 3, @agent.memories.journal.count
  end

  test "prompt includes core memories and numbered journal entries" do
    @agent.memories.create!(content: "I am a helpful assistant", memory_type: :core)

    prompt = MemoryReflectionJob.new.send(
      :build_prompt,
      @agent,
      @agent.memories.core.pluck(:content),
      @agent.memories.active_journal.order(:created_at)
    )

    assert_includes prompt, "I am a helpful assistant"
    assert_includes prompt, "1. ["
    assert_includes prompt, "User prefers concise answers"
    assert_includes prompt, "Respond ONLY with valid JSON"
  end

  test "malformed JSON promotes nothing" do
    indices = MemoryReflectionJob.new.send(:parse_response, Struct.new(:content).new("This is not valid JSON"))

    assert_equal [], indices
  end

  test "ignores invalid promotion indices" do
    MemoryReflectionJob.new.send(:promote_memories, @agent.memories.journal.order(:created_at), [ 1, 99 ])

    assert_equal 1, @agent.memories.core.count
    assert_predicate @journal1.reload, :core?
    assert_predicate @journal2.reload, :journal?
  end

end
