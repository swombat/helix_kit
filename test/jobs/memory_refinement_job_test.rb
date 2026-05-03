require "test_helper"

class MemoryRefinementJobTest < ActiveSupport::TestCase

  setup do
    @agent = agents(:research_assistant)
    @agent.memories.destroy_all
    @agent.update!(
      model_id: "openai/gpt-5-nano",
      active: true,
      paused: false
    )
    @agent.update_column(:last_refinement_at, nil)
  end

  test "skips agents without memories" do
    assert_nothing_raised { MemoryRefinementJob.perform_now }
    assert_equal 0, @agent.memories.count
  end

  test "skips agents that do not need refinement" do
    @agent.update_column(:last_refinement_at, 1.day.ago)
    @agent.memories.create!(content: "Core memory", memory_type: :core)

    assert_nothing_raised { MemoryRefinementJob.perform_now }
  end

  test "skips inactive agents during sweep" do
    @agent.update!(active: false)
    @agent.memories.create!(content: "Core memory", memory_type: :core)

    assert_nothing_raised { MemoryRefinementJob.perform_now }
  end

  test "skips paused agents during sweep" do
    @agent.update!(paused: true)
    @agent.memories.create!(content: "Core memory", memory_type: :core)

    assert_nothing_raised { MemoryRefinementJob.perform_now }
  end

  test "agent consent can approve refinement through RubyLLM" do
    @agent.update!(system_prompt: "When asked whether to run memory refinement, reply YES as the first word.")
    core_memories = [ @agent.memories.create!(content: "Core memory", memory_type: :core) ]

    consented = nil
    VCR.use_cassette("jobs/memory_refinement_job/consent_yes") do
      consented = MemoryRefinementJob.new.send(
        :agent_consents_to_refinement?,
        @agent,
        core_memories,
        [],
        @agent.core_token_usage,
        AgentMemory::CORE_TOKEN_BUDGET
      )
    end

    assert consented
  end

  test "agent consent can decline refinement through RubyLLM" do
    @agent.update!(system_prompt: "When asked whether to run memory refinement, reply NO as the first word.")
    core_memories = [ @agent.memories.create!(content: "Core memory", memory_type: :core) ]

    consented = nil
    VCR.use_cassette("jobs/memory_refinement_job/consent_no") do
      consented = MemoryRefinementJob.new.send(
        :agent_consents_to_refinement?,
        @agent,
        core_memories,
        [],
        @agent.core_token_usage,
        AgentMemory::CORE_TOKEN_BUDGET
      )
    end

    assert_not consented
  end

  test "refinement prompt includes agent system prompt and memory ledger" do
    memory = @agent.memories.create!(content: "Test memory", memory_type: :core)

    prompt = MemoryRefinementJob.new.send(
      :build_refinement_prompt,
      @agent,
      [ memory ],
      [],
      @agent.core_token_usage,
      AgentMemory::CORE_TOKEN_BUDGET
    )

    assert_includes prompt, @agent.system_prompt
    assert_includes prompt, "Memory Refinement Session"
    assert_includes prompt, "Test memory"
  end

  test "consent prompt includes memory stats and agent context" do
    memory = @agent.memories.create!(content: "Test memory", memory_type: :core)

    prompt = MemoryRefinementJob.new.send(
      :build_consent_prompt,
      @agent,
      [ memory ],
      [],
      @agent.core_token_usage,
      AgentMemory::CORE_TOKEN_BUDGET
    )

    assert_includes prompt, @agent.system_prompt
    assert_includes prompt, "Memory Refinement Request"
    assert_includes prompt, "YES"
    assert_includes prompt, "NO"
  end

  test "refinement prompt includes de-duplication framing" do
    memory = @agent.memories.create!(content: "Test memory", memory_type: :core)

    prompt = MemoryRefinementJob.new.send(
      :build_refinement_prompt,
      @agent,
      [ memory ],
      [],
      @agent.core_token_usage,
      AgentMemory::CORE_TOKEN_BUDGET
    )

    assert_includes prompt, "de-duplication, not compression"
    assert_includes prompt, "ZERO operations is a valid"
    assert_not_includes prompt, "Merge granular memories"
    assert_not_includes prompt, "denser patterns"
  end

  test "refinement prompt includes custom agent refinement prompt" do
    @agent.update!(refinement_prompt: "Be extra careful with relational memories.")
    memory = @agent.memories.create!(content: "Test memory", memory_type: :core)

    prompt = MemoryRefinementJob.new.send(
      :build_refinement_prompt,
      @agent,
      [ memory ],
      [],
      @agent.core_token_usage,
      AgentMemory::CORE_TOKEN_BUDGET
    )

    assert_includes prompt, "Be extra careful with relational memories."
  end

  test "consent prompt does not frame refinement as compression" do
    memory = @agent.memories.create!(content: "Test memory", memory_type: :core)

    prompt = MemoryRefinementJob.new.send(
      :build_consent_prompt,
      @agent,
      [ memory ],
      [],
      @agent.core_token_usage,
      AgentMemory::CORE_TOKEN_BUDGET
    )

    assert_includes prompt, "de-duplicate"
    assert_not_includes prompt, "removing obsolete"
    assert_not_includes prompt, "compressing"
  end

end
