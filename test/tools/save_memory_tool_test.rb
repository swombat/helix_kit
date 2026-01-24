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
    assert_includes result[:error], "Invalid memory_type"
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

  # Hallucination recovery interface tests

  test "recoverable_from? returns true for memory-like JSON" do
    assert SaveMemoryTool.recoverable_from?({ "memory_type" => "journal", "content" => "test" })
  end

  test "recoverable_from? returns true when JSON has extra fields" do
    assert SaveMemoryTool.recoverable_from?({
      "success" => true,
      "memory_type" => "journal",
      "content" => "test",
      "expires_around" => "2026-01-31"
    })
  end

  test "recoverable_from? returns false for non-memory JSON" do
    assert_not SaveMemoryTool.recoverable_from?({ "url" => "http://example.com" })
  end

  test "recoverable_from? returns false for JSON missing memory_type" do
    assert_not SaveMemoryTool.recoverable_from?({ "content" => "test" })
  end

  test "recoverable_from? returns false for JSON missing content" do
    assert_not SaveMemoryTool.recoverable_from?({ "memory_type" => "journal" })
  end

  test "recoverable_from? returns false for non-hash input" do
    assert_not SaveMemoryTool.recoverable_from?([])
    assert_not SaveMemoryTool.recoverable_from?("string")
    assert_not SaveMemoryTool.recoverable_from?(nil)
  end

  test "recover_from_hallucination creates journal memory" do
    agent = agents(:with_save_memory_tool)

    result = SaveMemoryTool.recover_from_hallucination(
      { "memory_type" => "journal", "content" => "Test content" },
      agent: agent,
      chat: nil
    )

    assert result[:success]
    assert_equal "SaveMemoryTool", result[:tool_name]
    assert agent.memories.exists?(content: "Test content", memory_type: "journal")
  end

  test "recover_from_hallucination creates core memory" do
    agent = agents(:with_save_memory_tool)

    result = SaveMemoryTool.recover_from_hallucination(
      { "memory_type" => "core", "content" => "Core identity" },
      agent: agent,
      chat: nil
    )

    assert result[:success]
    assert_equal "SaveMemoryTool", result[:tool_name]
    assert agent.memories.exists?(content: "Core identity", memory_type: "core")
  end

  test "recover_from_hallucination strips whitespace from content" do
    agent = agents(:with_save_memory_tool)

    result = SaveMemoryTool.recover_from_hallucination(
      { "memory_type" => "journal", "content" => "  Padded content  " },
      agent: agent,
      chat: nil
    )

    assert result[:success]
    assert agent.memories.exists?(content: "Padded content")
  end

  test "recover_from_hallucination returns error for missing memory_type" do
    agent = agents(:with_save_memory_tool)

    result = SaveMemoryTool.recover_from_hallucination(
      { "content" => "Test" },
      agent: agent,
      chat: nil
    )

    assert result[:error]
    assert_includes result[:error], "Missing memory_type"
  end

  test "recover_from_hallucination returns error for missing content" do
    agent = agents(:with_save_memory_tool)

    result = SaveMemoryTool.recover_from_hallucination(
      { "memory_type" => "journal" },
      agent: agent,
      chat: nil
    )

    assert result[:error]
    assert_includes result[:error], "Missing memory_type or content"
  end

  test "recover_from_hallucination returns error for invalid memory_type" do
    agent = agents(:with_save_memory_tool)

    result = SaveMemoryTool.recover_from_hallucination(
      { "memory_type" => "invalid", "content" => "Test" },
      agent: agent,
      chat: nil
    )

    assert result[:error]
    assert_includes result[:error], "Invalid memory_type"
  end

  test "recover_from_hallucination returns error for blank content" do
    agent = agents(:with_save_memory_tool)

    result = SaveMemoryTool.recover_from_hallucination(
      { "memory_type" => "journal", "content" => "   " },
      agent: agent,
      chat: nil
    )

    assert result[:error]
    assert_includes result[:error], "Failed to save memory"
    assert_includes result[:error], "Content can't be blank"
  end

  test "recover_from_hallucination handles hallucinated response format" do
    # This is what models like Gemini actually generate
    agent = agents(:with_save_memory_tool)

    result = SaveMemoryTool.recover_from_hallucination(
      {
        "success" => true,
        "memory_type" => "journal",
        "content" => "User prefers dark mode",
        "expires_around" => "2026-01-31"
      },
      agent: agent,
      chat: nil
    )

    assert result[:success]
    assert agent.memories.exists?(content: "User prefers dark mode")
  end

end
