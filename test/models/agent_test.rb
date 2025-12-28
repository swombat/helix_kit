require "test_helper"

class AgentTest < ActiveSupport::TestCase

  setup do
    @account = accounts(:personal_account)
  end

  test "creates agent with valid attributes" do
    agent = @account.agents.create!(
      name: "Test Agent",
      system_prompt: "You are helpful",
      model_id: "openrouter/auto"
    )
    assert agent.persisted?
  end

  test "requires name" do
    agent = @account.agents.build(name: nil)
    assert_not agent.valid?
    assert_includes agent.errors[:name], "can't be blank"
  end

  test "requires unique name within account" do
    @account.agents.create!(name: "Unique Name")
    duplicate = @account.agents.build(name: "Unique Name")
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:name], "has already been taken"
  end

  test "allows same name in different accounts" do
    other_account = accounts(:team_account)
    @account.agents.create!(name: "Shared Name")
    agent2 = other_account.agents.create!(name: "Shared Name")
    assert agent2.persisted?
  end

  test "validates enabled_tools against available tools" do
    agent = @account.agents.build(name: "Test", enabled_tools: [ "NonExistentTool" ])
    assert_not agent.valid?
    assert_includes agent.errors[:enabled_tools].first, "NonExistentTool"
  end

  test "discovers available tools" do
    tools = Agent.available_tools
    assert tools.is_a?(Array)
  end

  test "returns enabled tool classes" do
    available_tool_names = Agent.available_tools.map(&:name)
    if available_tool_names.include?("WebFetchTool")
      agent = @account.agents.create!(name: "Test", enabled_tools: [ "WebFetchTool" ])
      assert_includes agent.tools.map(&:name), "WebFetchTool"
    end
  end

  test "defaults to active" do
    agent = @account.agents.create!(name: "Test")
    assert agent.active?
  end

  test "model_label returns friendly name for known models" do
    agent = @account.agents.create!(name: "Test", model_id: "openai/gpt-5.2")
    assert_equal "GPT-5.2", agent.model_label
  end

  test "model_label falls back to model_id for unknown models" do
    agent = @account.agents.create!(name: "Test", model_id: "unknown/model")
    assert_equal "unknown/model", agent.model_label
  end

  test "active scope returns only active agents" do
    active_count = @account.agents.active.count
    inactive = agents(:inactive_agent)
    assert_not_includes @account.agents.active, inactive
  end

  test "by_name scope orders by name" do
    agents = @account.agents.by_name
    names = agents.map(&:name)
    assert_equal names.sort, names
  end

  test "validates system_prompt length" do
    agent = @account.agents.build(
      name: "Test",
      system_prompt: "x" * 50_001
    )
    assert_not agent.valid?
    assert_includes agent.errors[:system_prompt].first, "too long"
  end

  test "validates name length" do
    agent = @account.agents.build(name: "x" * 101)
    assert_not agent.valid?
    assert_includes agent.errors[:name].first, "too long"
  end

  # Reflection prompt tests

  test "accepts valid reflection_prompt" do
    agent = @account.agents.create!(
      name: "Test Agent",
      reflection_prompt: "Custom reflection prompt with %{system_prompt} and %{existing_memories}"
    )
    assert agent.persisted?
    assert_equal "Custom reflection prompt with %{system_prompt} and %{existing_memories}", agent.reflection_prompt
  end

  test "validates reflection_prompt length" do
    agent = @account.agents.build(
      name: "Test",
      reflection_prompt: "x" * 10_001
    )
    assert_not agent.valid?
    assert_includes agent.errors[:reflection_prompt].first, "too long"
  end

  test "allows empty reflection_prompt" do
    agent = @account.agents.create!(
      name: "Test Agent",
      reflection_prompt: nil
    )
    assert agent.persisted?
    assert_nil agent.reflection_prompt
  end

  test "includes reflection_prompt in json_attributes" do
    agent = @account.agents.create!(
      name: "Test Agent",
      reflection_prompt: "Custom prompt"
    )
    json = agent.as_json
    assert_equal "Custom prompt", json["reflection_prompt"]
  end

  # Memory context tests

  test "memory_context returns nil when no memories" do
    agent = @account.agents.create!(name: "Empty Agent")
    assert_nil agent.memory_context
  end

  test "memory_context formats core memories correctly" do
    agent = @account.agents.create!(name: "Agent With Memory")
    agent.memories.create!(content: "I am helpful", memory_type: :core)

    context = agent.memory_context
    assert_includes context, "Core Memories"
    assert_includes context, "I am helpful"
  end

  test "memory_context formats journal entries with dates" do
    agent = @account.agents.create!(name: "Agent With Journal")
    agent.memories.create!(content: "Met a user", memory_type: :journal)

    context = agent.memory_context
    assert_includes context, "Recent Journal Entries"
    assert_includes context, "Met a user"
    assert_match(/\d{4}-\d{2}-\d{2}/, context)
  end

  test "memory_context excludes expired journal entries" do
    agent = @account.agents.create!(name: "Agent With Old Journal")
    memory = agent.memories.create!(content: "Old news", memory_type: :journal)
    memory.update_column(:created_at, 2.weeks.ago)

    assert_nil agent.memory_context
  end

  test "memories_count returns correct counts" do
    agent = @account.agents.create!(name: "Agent With Memories")
    agent.memories.create!(content: "Core 1", memory_type: :core)
    agent.memories.create!(content: "Core 2", memory_type: :core)
    agent.memories.create!(content: "Journal 1", memory_type: :journal)

    counts = agent.memories_count
    assert_equal 2, counts[:core]
    assert_equal 1, counts[:journal]
  end

  test "memories_count returns zeros when no memories" do
    agent = @account.agents.create!(name: "Empty Agent")

    counts = agent.memories_count
    assert_equal 0, counts[:core]
    assert_equal 0, counts[:journal]
  end

end
