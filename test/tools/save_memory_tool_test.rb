require "test_helper"

class SaveMemoryToolTest < ActiveSupport::TestCase

  setup do
    @agent = agents(:research_assistant)
    @chat = nil  # The tool doesn't actually use the chat parameter for anything
  end

  test "creates journal memory successfully" do
    tool = SaveMemoryTool.new(chat: @chat, current_agent: @agent)

    result = tool.execute(content: "Today I learned something", memory_type: "journal")

    assert result[:success]
    assert_equal "journal", result[:memory_type]
    assert result[:expires_around].present?
    assert_equal 1, @agent.memories.journal.count

    memory = @agent.memories.journal.last
    assert_equal "Today I learned something", memory.content
  end

  test "creates core memory successfully" do
    tool = SaveMemoryTool.new(chat: @chat, current_agent: @agent)

    result = tool.execute(content: "I believe in helping others", memory_type: "core")

    assert result[:success]
    assert_equal "core", result[:memory_type]
    assert_equal "This memory is now part of your permanent identity", result[:note]
    assert_equal 1, @agent.memories.core.count

    memory = @agent.memories.core.last
    assert_equal "I believe in helping others", memory.content
  end

  test "fails without current_agent" do
    tool = SaveMemoryTool.new(chat: @chat, current_agent: nil)

    result = tool.execute(content: "Test", memory_type: "journal")

    assert result[:error]
    assert_includes result[:error], "group conversations"
  end

  test "fails with invalid memory_type" do
    tool = SaveMemoryTool.new(chat: @chat, current_agent: @agent)

    result = tool.execute(content: "Test", memory_type: "invalid")

    assert result[:error]
    assert_includes result[:error], "must be 'journal' or 'core'"
  end

  test "fails with blank content via model validation" do
    tool = SaveMemoryTool.new(chat: @chat, current_agent: @agent)

    result = tool.execute(content: "   ", memory_type: "journal")

    assert result[:error]
    assert_includes result[:error], "Content can't be blank"
  end

  test "fails with too long content via model validation" do
    tool = SaveMemoryTool.new(chat: @chat, current_agent: @agent)

    result = tool.execute(content: "x" * 10_001, memory_type: "journal")

    assert result[:error]
    assert_includes result[:error], "too long"
  end

end
