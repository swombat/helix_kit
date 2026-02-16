require "test_helper"
require "ostruct"

class MemoryRefinementJobTest < ActiveSupport::TestCase

  setup do
    @agent = agents(:research_assistant)
    @agent.memories.destroy_all
    @agent.update_column(:last_refinement_at, nil)
  end

  test "skips agents without core memories" do
    assert_no_llm_calls { MemoryRefinementJob.perform_now }
  end

  test "skips agents that do not need refinement" do
    @agent.update_column(:last_refinement_at, 1.day.ago)
    assert_no_llm_calls { MemoryRefinementJob.perform_now }
  end

  test "skips inactive agents" do
    @agent.update!(active: false)
    @agent.memories.create!(content: "Something", memory_type: :core)
    assert_no_llm_calls { MemoryRefinementJob.perform_now }
  end

  test "runs refinement when agent consents" do
    @agent.memories.create!(content: "Core memory", memory_type: :core)

    refinement_called = false

    stub_consent_and_refinement("YES", on_refinement: -> { refinement_called = true }) do
      MemoryRefinementJob.perform_now
    end

    assert refinement_called, "Expected refinement to run after agent consented"
  end

  test "skips refinement when agent declines consent" do
    @agent.memories.create!(content: "Core memory", memory_type: :core)

    refinement_called = false

    stub_consent_and_refinement("NO, I'd prefer not to right now.", on_refinement: -> { refinement_called = true }) do
      MemoryRefinementJob.perform_now
    end

    assert_not refinement_called, "Refinement should not run when agent declines"
  end

  test "runs refinement for specific agent_id with consent" do
    @agent.memories.create!(content: "Core memory", memory_type: :core)

    refinement_called = false

    stub_consent_and_refinement("YES", on_refinement: -> { refinement_called = true }) do
      MemoryRefinementJob.perform_now(@agent.id)
    end

    assert refinement_called
  end

  test "continues processing if one agent fails" do
    agent2 = agents(:code_reviewer)
    agent2.memories.destroy_all
    agent2.update_column(:last_refinement_at, nil)
    @agent.memories.create!(content: "Memory 1", memory_type: :core)
    agent2.memories.create!(content: "Memory 2", memory_type: :core)

    consent_count = 0
    refinement_count = 0

    mock_factory = ->(**opts) {
      mock = Object.new
      has_tool = false
      mock.define_singleton_method(:with_tool) { |_t| has_tool = true; self }
      mock.define_singleton_method(:ask) do |_prompt|
        unless has_tool
          consent_count += 1
          return OpenStruct.new(content: "YES")
        end
        refinement_count += 1
        raise "Simulated error" if refinement_count == 1
        OpenStruct.new(content: "Done")
      end
      mock
    }

    RubyLLM.stub :chat, mock_factory do
      MemoryRefinementJob.perform_now
    end

    assert_equal 2, consent_count, "Both agents should be asked for consent"
    assert_equal 2, refinement_count, "Both agents should attempt refinement"
  end

  test "refinement prompt includes agent system prompt" do
    @agent.memories.create!(content: "Test memory", memory_type: :core)

    refinement_prompt = nil

    stub_consent_and_refinement("YES", capture_refinement_prompt: ->(p) { refinement_prompt = p }) do
      MemoryRefinementJob.perform_now(@agent.id)
    end

    assert_includes refinement_prompt, @agent.system_prompt
    assert_includes refinement_prompt, "Memory Refinement Session"
    assert_includes refinement_prompt, "Test memory"
  end

  test "consent prompt includes memory stats and agent context" do
    @agent.memories.create!(content: "Test memory", memory_type: :core)

    consent_prompt = nil

    stub_consent_and_refinement("NO", capture_consent_prompt: ->(p) { consent_prompt = p }) do
      MemoryRefinementJob.perform_now(@agent.id)
    end

    assert_includes consent_prompt, @agent.system_prompt
    assert_includes consent_prompt, "Memory Refinement Request"
    assert_includes consent_prompt, "YES"
    assert_includes consent_prompt, "NO"
  end

  # New prompt assertion tests

  test "refinement prompt includes de-duplication framing" do
    @agent.memories.create!(content: "Test memory", memory_type: :core)

    refinement_prompt = nil

    stub_consent_and_refinement("YES", capture_refinement_prompt: ->(p) { refinement_prompt = p }) do
      MemoryRefinementJob.perform_now(@agent.id)
    end

    assert_includes refinement_prompt, "de-duplication, not compression"
    assert_includes refinement_prompt, "AT MOST 10 mutating operations"
    assert_includes refinement_prompt, "ZERO operations is a valid"
    assert_not_includes refinement_prompt, "Merge granular memories"
    assert_not_includes refinement_prompt, "denser patterns"
  end

  test "refinement prompt includes agent refinement_prompt when set" do
    @agent.update!(refinement_prompt: "Be extra careful with relational memories.")
    @agent.memories.create!(content: "Test memory", memory_type: :core)

    refinement_prompt = nil

    stub_consent_and_refinement("YES", capture_refinement_prompt: ->(p) { refinement_prompt = p }) do
      MemoryRefinementJob.perform_now(@agent.id)
    end

    assert_includes refinement_prompt, "Be extra careful with relational memories."
  end

  test "refinement prompt uses default when agent has no custom refinement_prompt" do
    @agent.memories.create!(content: "Test memory", memory_type: :core)

    refinement_prompt = nil

    stub_consent_and_refinement("YES", capture_refinement_prompt: ->(p) { refinement_prompt = p }) do
      MemoryRefinementJob.perform_now(@agent.id)
    end

    assert_includes refinement_prompt, Agent::DEFAULT_REFINEMENT_PROMPT
  end

  test "consent prompt does not mention compression" do
    @agent.memories.create!(content: "Test memory", memory_type: :core)

    consent_prompt = nil

    stub_consent_and_refinement("NO", capture_consent_prompt: ->(p) { consent_prompt = p }) do
      MemoryRefinementJob.perform_now(@agent.id)
    end

    assert_includes consent_prompt, "de-duplicate"
    assert_not_includes consent_prompt, "removing obsolete"
    assert_not_includes consent_prompt, "compressing"
  end

  private

  def assert_no_llm_calls(&block)
    chat_called = false
    mock = Object.new
    mock.define_singleton_method(:with_tool) { |_t| self }
    mock.define_singleton_method(:ask) { |_p| chat_called = true; OpenStruct.new(content: "Done") }

    RubyLLM.stub :chat, ->(**opts) { mock } do
      block.call
    end

    assert_not chat_called, "LLM should not have been called"
  end

  def stub_consent_and_refinement(consent_answer, on_refinement: nil,
                                  capture_refinement_prompt: nil,
                                  capture_consent_prompt: nil)
    mock_factory = ->(**opts) {
      mock = Object.new
      has_tool = false
      mock.define_singleton_method(:with_tool) { |_t| has_tool = true; self }
      mock.define_singleton_method(:ask) do |prompt|
        unless has_tool
          capture_consent_prompt&.call(prompt)
          return OpenStruct.new(content: consent_answer)
        end
        on_refinement&.call
        capture_refinement_prompt&.call(prompt)
        OpenStruct.new(content: "Done")
      end
      mock
    }

    RubyLLM.stub :chat, mock_factory do
      yield
    end
  end

end
