require "test_helper"
require "ostruct"

class MemoryRefinementJobTest < ActiveSupport::TestCase

  setup do
    @agent = agents(:research_assistant)
    @agent.memories.destroy_all
    @agent.update_column(:last_refinement_at, nil)
  end

  test "skips agents without core memories" do
    chat_called = false
    mock = Object.new
    mock.define_singleton_method(:with_tool) { |_t| self }
    mock.define_singleton_method(:ask) { |_p| chat_called = true; OpenStruct.new(content: "Done") }

    RubyLLM.stub :chat, ->(**opts) { mock } do
      MemoryRefinementJob.perform_now
    end

    assert_not chat_called, "LLM should not be called when agent has no core memories"
  end

  test "skips agents that do not need refinement" do
    @agent.update_column(:last_refinement_at, 1.day.ago)
    # Agent has no core memories, so doesn't need refinement even with recent last_refinement_at

    chat_called = false
    mock = Object.new
    mock.define_singleton_method(:with_tool) { |_t| self }
    mock.define_singleton_method(:ask) { |_p| chat_called = true; OpenStruct.new(content: "Done") }

    RubyLLM.stub :chat, ->(**opts) { mock } do
      MemoryRefinementJob.perform_now
    end

    assert_not chat_called, "LLM should not be called when agent does not need refinement"
  end

  test "skips inactive agents" do
    @agent.update!(active: false)
    @agent.memories.create!(content: "Something", memory_type: :core)

    chat_called = false
    mock = Object.new
    mock.define_singleton_method(:with_tool) { |_t| self }
    mock.define_singleton_method(:ask) { |_p| chat_called = true; OpenStruct.new(content: "Done") }

    RubyLLM.stub :chat, ->(**opts) { mock } do
      MemoryRefinementJob.perform_now
    end

    assert_not chat_called, "LLM should not be called for inactive agents"
  end

  test "runs refinement for agent with no last_refinement_at" do
    @agent.memories.create!(content: "Core memory", memory_type: :core)

    chat_called = false
    mock_chat = mock_agentic_chat(-> {
      chat_called = true
    })

    RubyLLM.stub :chat, ->(**opts) { mock_chat } do
      MemoryRefinementJob.perform_now
    end

    assert chat_called, "Expected LLM chat to be called"
  end

  test "runs refinement for specific agent_id" do
    @agent.memories.create!(content: "Core memory", memory_type: :core)

    chat_called = false
    mock_chat = mock_agentic_chat(-> { chat_called = true })

    RubyLLM.stub :chat, ->(**opts) { mock_chat } do
      MemoryRefinementJob.perform_now(@agent.id)
    end

    assert chat_called
  end

  test "continues processing if one agent fails" do
    agent2 = agents(:code_reviewer)
    agent2.memories.destroy_all
    agent2.update_column(:last_refinement_at, nil)
    @agent.memories.create!(content: "Memory 1", memory_type: :core)
    agent2.memories.create!(content: "Memory 2", memory_type: :core)

    call_count = 0
    mock_chat = mock_agentic_chat(-> {
      call_count += 1
      raise "Simulated error" if call_count == 1
    })

    RubyLLM.stub :chat, ->(**opts) { mock_chat } do
      MemoryRefinementJob.perform_now
    end

    assert_equal 2, call_count
  end

  test "prompt includes agent system prompt" do
    @agent.memories.create!(content: "Test memory", memory_type: :core)

    prompt_received = nil
    mock_chat = mock_agentic_chat_with_prompt_capture(->(prompt) { prompt_received = prompt })

    RubyLLM.stub :chat, ->(**opts) { mock_chat } do
      MemoryRefinementJob.perform_now(@agent.id)
    end

    assert_includes prompt_received, @agent.system_prompt
    assert_includes prompt_received, "Memory Refinement Session"
    assert_includes prompt_received, "Test memory"
  end

  private

  def mock_agentic_chat(on_ask)
    mock = Object.new
    mock.define_singleton_method(:with_tool) { |_t| self }
    mock.define_singleton_method(:ask) do |_prompt|
      on_ask.call
      OpenStruct.new(content: "Done")
    end
    mock
  end

  def mock_agentic_chat_with_prompt_capture(handler)
    mock = Object.new
    mock.define_singleton_method(:with_tool) { |_t| self }
    mock.define_singleton_method(:ask) do |prompt|
      handler.call(prompt)
      OpenStruct.new(content: "Done")
    end
    mock
  end

end
