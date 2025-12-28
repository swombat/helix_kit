require "test_helper"
require "ostruct"

class MemoryReflectionJobTest < ActiveSupport::TestCase

  setup do
    @agent = agents(:research_assistant)
    @agent.memories.destroy_all

    # Create some journal entries
    @journal1 = @agent.memories.create!(content: "User prefers concise answers", memory_type: :journal)
    @journal2 = @agent.memories.create!(content: "Discussed project deadline of Jan 15", memory_type: :journal)
    @journal3 = @agent.memories.create!(content: "I work best when I ask clarifying questions", memory_type: :journal)
  end

  test "skips agents without recent journal entries" do
    @agent.memories.journal.destroy_all

    # Should complete without calling LLM
    MemoryReflectionJob.perform_now

    assert_equal 0, @agent.memories.core.count
  end

  test "skips agents with only expired journal entries" do
    @agent.memories.journal.update_all(created_at: 2.weeks.ago)

    MemoryReflectionJob.perform_now

    assert_equal 0, @agent.memories.core.count
  end

  test "promotes selected journal entries to core" do
    # Agent selects entries 1 and 3
    response = { "promote" => [ 1, 3 ] }

    mock_llm_response(response.to_json) do
      MemoryReflectionJob.perform_now
    end

    @journal1.reload
    @journal2.reload
    @journal3.reload

    assert @journal1.core?, "Entry 1 should be promoted to core"
    assert @journal2.journal?, "Entry 2 should remain journal"
    assert @journal3.core?, "Entry 3 should be promoted to core"

    # Total memory count unchanged - we updated, not created
    assert_equal 3, @agent.memories.count
    assert_equal 2, @agent.memories.core.count
  end

  test "handles empty promotion list - agent chooses nothing" do
    response = { "promote" => [] }

    mock_llm_response(response.to_json) do
      MemoryReflectionJob.perform_now
    end

    # All should remain as journal
    assert_equal 0, @agent.memories.core.count
    assert_equal 3, @agent.memories.journal.count
  end

  test "handles malformed JSON gracefully" do
    mock_llm_response("This is not valid JSON") do
      MemoryReflectionJob.perform_now
    end

    # Should not raise, should not promote anything
    assert_equal 0, @agent.memories.core.count
  end

  test "ignores invalid indices" do
    # Index 99 doesn't exist
    response = { "promote" => [ 1, 99 ] }

    mock_llm_response(response.to_json) do
      MemoryReflectionJob.perform_now
    end

    # Only entry 1 should be promoted
    assert_equal 1, @agent.memories.core.count
    @journal1.reload
    assert @journal1.core?
  end

  test "includes core memories and numbered journal entries in prompt" do
    @agent.memories.create!(content: "I am a helpful assistant", memory_type: :core)

    prompt_received = nil

    mock_llm_with_prompt_capture(->(prompt) {
      prompt_received = prompt
      '{"promote": []}'
    }) do
      MemoryReflectionJob.perform_now
    end

    assert_includes prompt_received, "I am a helpful assistant"
    assert_includes prompt_received, "1. ["  # Numbered entries
    assert_includes prompt_received, "User prefers concise answers"
  end

  test "continues processing other agents if one fails" do
    agent2 = agents(:code_reviewer)
    agent2.memories.create!(content: "Some observation", memory_type: :journal)

    call_count = 0

    mock_chat = Class.new do
      define_method(:initialize) do |counter_ref|
        @counter_ref = counter_ref
      end

      define_method(:ask) do |prompt|
        @counter_ref[:count] += 1
        raise "Simulated error" if @counter_ref[:count] == 1
        OpenStruct.new(content: '{"promote": []}')
      end
    end

    counter = { count: 0 }

    RubyLLM.stub :chat, ->(**opts) { mock_chat.new(counter) } do
      MemoryReflectionJob.perform_now
    end

    # Should have attempted both agents
    assert_equal 2, counter[:count]
  end

  private

  def mock_llm_response(content)
    response = OpenStruct.new(content: content)
    mock_chat = Object.new
    mock_chat.define_singleton_method(:ask) { |_prompt| response }

    RubyLLM.stub :chat, ->(**opts) { mock_chat } do
      yield
    end
  end

  def mock_llm_with_prompt_capture(handler)
    mock_chat = Object.new
    mock_chat.define_singleton_method(:ask) do |prompt|
      OpenStruct.new(content: handler.call(prompt))
    end

    RubyLLM.stub :chat, ->(**opts) { mock_chat } do
      yield
    end
  end

end
