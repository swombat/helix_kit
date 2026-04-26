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
    if available_tool_names.include?("WebTool")
      agent = @account.agents.create!(name: "Test", enabled_tools: [ "WebTool" ])
      assert_includes agent.tools.map(&:name), "WebTool"
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

  # ----- paused -----

  test "defaults paused to false" do
    agent = @account.agents.create!(name: "Default Paused")
    assert_not agent.paused?
  end

  test "unpaused scope excludes paused agents" do
    active_one = @account.agents.create!(name: "Active One")
    paused = @account.agents.create!(name: "Paused One", paused: true)
    assert_includes @account.agents.unpaused, active_one
    assert_not_includes @account.agents.unpaused, paused
  end

  test "paused is independent of active" do
    paused_active = @account.agents.create!(name: "Paused but Active", paused: true, active: true)
    assert paused_active.active?
    assert paused_active.paused?
    # The agent still appears in active scope (because active is about availability,
    # not auto-trigger behavior)
    assert_includes @account.agents.active, paused_active
    # But not in unpaused
    assert_not_includes @account.agents.unpaused, paused_active
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

  test "as_json list excludes memory stats" do
    agent = @account.agents.create!(name: "List Agent")
    agent.memories.create!(content: "Core memory", memory_type: :core)

    json = agent.as_json(as: :list)

    assert_equal "List Agent", json["name"]
    assert_nil json["memories_count"]
    assert_nil json["memory_token_summary"]
  end

  test "as_json includes memory stats by default" do
    agent = @account.agents.create!(name: "Full Agent")
    agent.memories.create!(content: "Core memory", memory_type: :core)

    json = agent.as_json

    assert_equal 1, json.dig("memories_count", "core")
    assert json["memory_token_summary"].is_a?(Hash)
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

  # Refinement threshold tests

  test "effective_refinement_threshold returns default when nil" do
    agent = @account.agents.create!(name: "Threshold Agent", refinement_threshold: nil)
    assert_equal Agent::DEFAULT_REFINEMENT_THRESHOLD, agent.effective_refinement_threshold
  end

  test "effective_refinement_threshold returns custom value when set" do
    agent = @account.agents.create!(name: "Custom Threshold Agent", refinement_threshold: 0.90)
    assert_equal 0.90, agent.effective_refinement_threshold
  end

  test "refinement_threshold validates range" do
    agent = @account.agents.build(name: "Range Test")

    agent.refinement_threshold = 0
    assert_not agent.valid?

    agent.refinement_threshold = 1.5
    assert_not agent.valid?

    agent.refinement_threshold = 0.75
    assert agent.valid?

    agent.refinement_threshold = nil
    assert agent.valid?
  end

  # Summary prompt tests

  test "validates summary_prompt length" do
    agent = @account.agents.build(
      name: "Test",
      summary_prompt: "x" * 10_001
    )
    assert_not agent.valid?
    assert_includes agent.errors[:summary_prompt].first, "too long"
  end

  test "effective_summary_prompt returns custom prompt when set" do
    agent = @account.agents.create!(
      name: "Custom Summary Agent",
      summary_prompt: "My custom summary instructions"
    )
    assert_equal "My custom summary instructions", agent.effective_summary_prompt
  end

  test "effective_summary_prompt returns default when blank" do
    agent = @account.agents.create!(name: "Default Summary Agent", summary_prompt: nil)
    assert_equal Agent::DEFAULT_SUMMARY_PROMPT, agent.effective_summary_prompt

    agent.update!(summary_prompt: "")
    assert_equal Agent::DEFAULT_SUMMARY_PROMPT, agent.effective_summary_prompt
  end

  test "includes summary_prompt in json_attributes" do
    agent = @account.agents.create!(name: "JSON Test", summary_prompt: "Custom prompt")
    json = agent.as_json
    assert_equal "Custom prompt", json["summary_prompt"]
  end

  # Refinement prompt tests

  test "effective_refinement_prompt returns custom prompt when set" do
    agent = @account.agents.create!(
      name: "Custom Refinement Agent",
      refinement_prompt: "My custom refinement instructions"
    )
    assert_equal "My custom refinement instructions", agent.effective_refinement_prompt
  end

  test "effective_refinement_prompt returns default when blank" do
    agent = @account.agents.create!(name: "Default Refinement Agent", refinement_prompt: nil)
    assert_equal Agent::DEFAULT_REFINEMENT_PROMPT, agent.effective_refinement_prompt

    agent.update!(refinement_prompt: "")
    assert_equal Agent::DEFAULT_REFINEMENT_PROMPT, agent.effective_refinement_prompt
  end

  test "validates refinement_prompt length" do
    agent = @account.agents.build(
      name: "Test",
      refinement_prompt: "x" * 10_001
    )
    assert_not agent.valid?
    assert_includes agent.errors[:refinement_prompt].first, "too long"
  end

  # other_conversation_summaries tests

  test "other_conversation_summaries returns summaries from other conversations and excludes specified chat" do
    agent = @account.agents.create!(name: "Multi-Chat Agent", model_id: "openrouter/auto")

    # Create two chats with the agent
    chat1 = @account.chats.new(title: "Chat 1", manual_responses: true, model_id: "openrouter/auto")
    chat1.agent_ids = [ agent.id ]
    chat1.save!

    chat2 = @account.chats.new(title: "Chat 2", manual_responses: true, model_id: "openrouter/auto")
    chat2.agent_ids = [ agent.id ]
    chat2.save!

    # Set summary on chat2's ChatAgent
    ca2 = ChatAgent.find_by(chat: chat2, agent: agent)
    ca2.update_columns(agent_summary: "Working on project X", agent_summary_generated_at: 1.minute.ago)

    summaries = agent.other_conversation_summaries(exclude_chat_id: chat1.id)
    assert_equal 1, summaries.length
    assert_equal "Working on project X", summaries.first.agent_summary
    assert_equal chat2.id, summaries.first.chat_id
  end

  test "other_conversation_summaries excludes conversations older than 6 hours" do
    agent = @account.agents.create!(name: "Old Chat Agent", model_id: "openrouter/auto")

    chat1 = @account.chats.new(title: "Current", manual_responses: true, model_id: "openrouter/auto")
    chat1.agent_ids = [ agent.id ]
    chat1.save!

    old_chat = @account.chats.new(title: "Old", manual_responses: true, model_id: "openrouter/auto")
    old_chat.agent_ids = [ agent.id ]
    old_chat.save!
    old_chat.update_columns(updated_at: 7.hours.ago)

    ca = ChatAgent.find_by(chat: old_chat, agent: agent)
    ca.update_columns(agent_summary: "Old summary", agent_summary_generated_at: 7.hours.ago)

    summaries = agent.other_conversation_summaries(exclude_chat_id: chat1.id)
    assert_empty summaries
  end

  test "other_conversation_summaries excludes discarded conversations" do
    agent = @account.agents.create!(name: "Discard Test Agent", model_id: "openrouter/auto")

    chat1 = @account.chats.new(title: "Active", manual_responses: true, model_id: "openrouter/auto")
    chat1.agent_ids = [ agent.id ]
    chat1.save!

    discarded_chat = @account.chats.new(title: "Discarded", manual_responses: true, model_id: "openrouter/auto")
    discarded_chat.agent_ids = [ agent.id ]
    discarded_chat.save!

    ca = ChatAgent.find_by(chat: discarded_chat, agent: agent)
    ca.update_columns(agent_summary: "Discarded chat summary", agent_summary_generated_at: 1.minute.ago)
    discarded_chat.discard!

    summaries = agent.other_conversation_summaries(exclude_chat_id: chat1.id)
    assert_empty summaries
  end

  test "other_conversation_summaries excludes blank summaries" do
    agent = @account.agents.create!(name: "Blank Summary Agent", model_id: "openrouter/auto")

    chat1 = @account.chats.new(title: "Current", manual_responses: true, model_id: "openrouter/auto")
    chat1.agent_ids = [ agent.id ]
    chat1.save!

    chat2 = @account.chats.new(title: "No Summary", manual_responses: true, model_id: "openrouter/auto")
    chat2.agent_ids = [ agent.id ]
    chat2.save!
    # No summary set -- should be excluded

    chat3 = @account.chats.new(title: "Empty Summary", manual_responses: true, model_id: "openrouter/auto")
    chat3.agent_ids = [ agent.id ]
    chat3.save!
    ca3 = ChatAgent.find_by(chat: chat3, agent: agent)
    ca3.update_columns(agent_summary: "", agent_summary_generated_at: 1.minute.ago)

    summaries = agent.other_conversation_summaries(exclude_chat_id: chat1.id)
    assert_empty summaries
  end

  test "other_conversation_summaries limits to 10 results" do
    agent = @account.agents.create!(name: "Many Chats Agent", model_id: "openrouter/auto")

    current_chat = @account.chats.new(title: "Current", manual_responses: true, model_id: "openrouter/auto")
    current_chat.agent_ids = [ agent.id ]
    current_chat.save!

    12.times do |i|
      chat = @account.chats.new(title: "Chat #{i}", manual_responses: true, model_id: "openrouter/auto")
      chat.agent_ids = [ agent.id ]
      chat.save!

      ca = ChatAgent.find_by(chat: chat, agent: agent)
      ca.update_columns(agent_summary: "Summary #{i}", agent_summary_generated_at: 1.minute.ago)
    end

    summaries = agent.other_conversation_summaries(exclude_chat_id: current_chat.id)
    assert_equal 10, summaries.length
  end

  # ----- upgrade_with_predecessor! -----
  # The agent itself (this row) keeps its id, conversations, telegram, voice —
  # only model_id changes. A predecessor agent is created carrying the OLD
  # model and a copy of all kept memories.

  test "upgrade_with_predecessor! changes self's model_id and preserves identity" do
    successor = @account.agents.create!(
      name: "Lume",
      system_prompt: "core prompt",
      model_id: "anthropic/claude-opus-4.6",
      thinking_enabled: true,
      thinking_budget: 12_000
    )
    successor_id = successor.id

    successor.upgrade_with_predecessor!(to_model: "anthropic/claude-opus-4.7")

    successor.reload
    assert_equal successor_id, successor.id
    assert_equal "Lume", successor.name
    assert_equal "anthropic/claude-opus-4.7", successor.model_id
    assert_equal "core prompt", successor.system_prompt
    assert_equal 12_000, successor.thinking_budget
  end

  test "upgrade_with_predecessor! creates predecessor with old model and copied prompts" do
    successor = @account.agents.create!(
      name: "Lume",
      system_prompt: "core prompt",
      reflection_prompt: "reflect",
      memory_reflection_prompt: "memory-reflect",
      summary_prompt: "summary",
      refinement_prompt: "refine",
      refinement_threshold: 0.85,
      model_id: "anthropic/claude-opus-4.6",
      colour: "violet",
      icon: "Sparkle",
      thinking_enabled: true,
      thinking_budget: 12_000
    )

    predecessor = successor.upgrade_with_predecessor!(to_model: "anthropic/claude-opus-4.7")

    assert predecessor.persisted?
    assert_not_equal successor.id, predecessor.id
    assert_equal successor.account_id, predecessor.account_id
    assert_equal "anthropic/claude-opus-4.6", predecessor.model_id
    assert_equal "core prompt", predecessor.system_prompt
    assert_equal "reflect", predecessor.reflection_prompt
    assert_equal "memory-reflect", predecessor.memory_reflection_prompt
    assert_equal "summary", predecessor.summary_prompt
    assert_equal "refine", predecessor.refinement_prompt
    assert_equal 0.85, predecessor.refinement_threshold
    assert_equal "violet", predecessor.colour
    assert_equal "Sparkle", predecessor.icon
    assert predecessor.thinking_enabled
    assert_equal 12_000, predecessor.thinking_budget
  end

  test "upgrade_with_predecessor! defaults predecessor name to '<name> (<old model label>)'" do
    successor = @account.agents.create!(name: "Lume", model_id: "anthropic/claude-opus-4.6")

    predecessor = successor.upgrade_with_predecessor!(to_model: "anthropic/claude-opus-4.7")

    assert_equal "Lume (Claude Opus 4.6)", predecessor.name
  end

  test "upgrade_with_predecessor! falls back to model_id when label is unknown" do
    successor = @account.agents.create!(name: "Custom", model_id: "some-unknown/model")

    predecessor = successor.upgrade_with_predecessor!(to_model: "anthropic/claude-opus-4.7")

    assert_equal "Custom (some-unknown/model)", predecessor.name
  end

  test "upgrade_with_predecessor! accepts an explicit predecessor name" do
    successor = @account.agents.create!(name: "Lume", model_id: "anthropic/claude-opus-4.6")

    predecessor = successor.upgrade_with_predecessor!(
      to_model: "anthropic/claude-opus-4.7",
      predecessor_name: "Lume — pre-4.7 self"
    )

    assert_equal "Lume — pre-4.7 self", predecessor.name
  end

  test "upgrade_with_predecessor! does NOT copy telegram credentials onto predecessor" do
    successor = @account.agents.create!(
      name: "Telegrammed",
      model_id: "anthropic/claude-opus-4.6",
      telegram_bot_token: "secret-token",
      telegram_bot_username: "lume_light_bot",
      telegram_webhook_token: SecureRandom.hex(16)
    )

    predecessor = successor.upgrade_with_predecessor!(to_model: "anthropic/claude-opus-4.7")

    assert_nil predecessor.telegram_bot_token
    assert_nil predecessor.telegram_bot_username
    assert_nil predecessor.telegram_webhook_token

    # And the successor keeps its telegram config — that's the whole point of succession
    successor.reload
    assert_equal "secret-token", successor.telegram_bot_token
    assert_equal "lume_light_bot", successor.telegram_bot_username
  end

  test "upgrade_with_predecessor! duplicates kept memories with metadata preserved" do
    successor = @account.agents.create!(name: "MemSource", model_id: "anthropic/claude-opus-4.6")
    core_at = 3.days.ago
    journal_at = 2.hours.ago
    successor.memories.create!(content: "core fact", memory_type: :core, constitutional: true, created_at: core_at)
    successor.memories.create!(content: "journal entry", memory_type: :journal, constitutional: false, created_at: journal_at)

    predecessor = successor.upgrade_with_predecessor!(to_model: "anthropic/claude-opus-4.7")

    assert_equal 2, predecessor.memories.kept.count

    core = predecessor.memories.find_by(content: "core fact")
    assert_equal "core", core.memory_type
    assert core.constitutional?
    assert_in_delta core_at.to_f, core.created_at.to_f, 1.0

    journal = predecessor.memories.find_by(content: "journal entry")
    assert_equal "journal", journal.memory_type
    assert_not journal.constitutional?
  end

  test "upgrade_with_predecessor! leaves successor's memories intact" do
    successor = @account.agents.create!(name: "Both", model_id: "anthropic/claude-opus-4.6")
    successor.memories.create!(content: "shared memory", memory_type: :core)

    successor.upgrade_with_predecessor!(to_model: "anthropic/claude-opus-4.7")

    successor.reload
    assert_equal 1, successor.memories.kept.count
    assert_equal "shared memory", successor.memories.kept.first.content
  end

  test "upgrade_with_predecessor! does not copy discarded memories to predecessor" do
    successor = @account.agents.create!(name: "DiscardSource", model_id: "anthropic/claude-opus-4.6")
    successor.memories.create!(content: "keep me", memory_type: :journal)
    tombstone = successor.memories.create!(content: "discard me", memory_type: :journal)
    tombstone.discard

    predecessor = successor.upgrade_with_predecessor!(to_model: "anthropic/claude-opus-4.7")

    assert_equal 1, predecessor.memories.count
    assert_equal "keep me", predecessor.memories.first.content
  end

  test "upgrade_with_predecessor! raises when to_model is blank" do
    successor = @account.agents.create!(name: "Source", model_id: "anthropic/claude-opus-4.6")

    assert_raises(ArgumentError) { successor.upgrade_with_predecessor!(to_model: "") }
    assert_raises(ArgumentError) { successor.upgrade_with_predecessor!(to_model: nil) }
  end

  test "upgrade_with_predecessor! raises and rolls back when predecessor name collides" do
    @account.agents.create!(name: "Lume (Claude Opus 4.6)", model_id: "openrouter/auto")
    successor = @account.agents.create!(name: "Lume", model_id: "anthropic/claude-opus-4.6")

    assert_raises(ActiveRecord::RecordInvalid) do
      successor.upgrade_with_predecessor!(to_model: "anthropic/claude-opus-4.7")
    end

    # Successor's model_id MUST NOT have changed — the transaction rolled back
    successor.reload
    assert_equal "anthropic/claude-opus-4.6", successor.model_id
  end

end
