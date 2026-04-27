# frozen_string_literal: true

require "test_helper"
require "vcr"

class MultiModelThinkingToolTest < ActiveSupport::TestCase

  # === Multi-Model Extended Thinking with Tool Use ===
  #
  # This test records a multi-turn conversation with multiple agents
  # (different models) using tools while thinking is enabled.
  #
  # Models tested:
  # - Claude Opus 4.5 (thinking via Anthropic direct API)
  # - GPT 5.2 (thinking via OpenRouter)
  # - Grok 4 (no thinking support - tests mixed conversation)
  #
  # To record new cassettes:
  # 1. Ensure valid API keys are configured in Rails credentials
  # 2. Delete existing cassette file
  # 3. Run: rails test test/integration/multi_model_thinking_tool_test.rb

  setup do
    # Use a fixed email for deterministic VCR cassettes
    @user = User.find_or_create_by!(email_address: "multimodel-test@example.com") do |u|
      u.password = "password123"
    end
    @user.profile.update!(first_name: "Test", last_name: "User")
    @account = @user.personal_account
  end

  test "multi-model conversation with thinking and tool use" do
    # Create agents with different models
    # Claude Opus 4.5 - thinking enabled, direct API
    opus_agent = @account.agents.create!(
      name: "Claude Opus",
      model_id: "anthropic/claude-opus-4.5",
      system_prompt: "You are Claude Opus. When asked to remember something, use the save_memory tool to store it as a 'journal' memory. Keep your response brief - just one sentence.",
      thinking_enabled: true,
      thinking_budget: 5000,
      enabled_tools: [ "SaveMemoryTool" ]
    )

    # GPT 5.2 - thinking enabled, OpenRouter
    gpt_agent = @account.agents.create!(
      name: "GPT",
      model_id: "openai/gpt-5.2",
      system_prompt: "You are GPT. When asked to remember something, use the save_memory tool to store it as a 'journal' memory. Keep your response brief - just one sentence.",
      thinking_enabled: true,
      thinking_budget: 5000,
      enabled_tools: [ "SaveMemoryTool" ]
    )

    # Grok 4 - no thinking support (tests mixed conversation)
    grok_agent = @account.agents.create!(
      name: "Grok",
      model_id: "x-ai/grok-4",
      system_prompt: "You are Grok. When asked to remember something, use the save_memory tool to store it as a 'journal' memory. Keep your response brief - just one sentence.",
      thinking_enabled: true, # Enabled but model doesn't support it
      thinking_budget: 5000,
      enabled_tools: [ "SaveMemoryTool" ]
    )

    # Verify thinking configuration
    assert opus_agent.uses_thinking?, "Opus should use thinking"
    assert gpt_agent.uses_thinking?, "GPT should use thinking"
    refute grok_agent.uses_thinking?, "Grok should NOT use thinking (model doesn't support it)"

    # Create group chat with all agents
    chat = @account.chats.new(
      model_id: "openai/gpt-4o", # Fallback model (not used for manual responses)
      manual_responses: true,
      title: "Multi-Model Thinking Test"
    )
    chat.agents = [ opus_agent, gpt_agent, grok_agent ]
    chat.save!

    # User asks all agents to remember something
    chat.messages.create!(
      role: "user",
      user: @user,
      content: "Each of you, please use the save_memory tool to remember the following fact about yourself: 'I participated in the multi-model thinking test'. Keep your response to one sentence after saving."
    )

    VCR.use_cassette("thinking/multi_model_tool_use", record: :new_episodes, match_requests_on: [ :method, :uri ]) do
      # Each agent responds in turn
      [ opus_agent, gpt_agent, grok_agent ].each do |agent|
        ManualAgentResponseJob.perform_now(chat, agent)
      end
    end

    # Verify each agent created at least one message with content
    # (Tool calls may create multiple message rounds per agent)
    agent_messages = chat.messages.where(role: "assistant").order(:created_at)
    assert agent_messages.count >= 3, "Expected at least 3 assistant messages (one per agent)"

    # Check Opus response (thinking enabled) - get last message with content
    opus_msgs = agent_messages.select { |m| m.agent_id == opus_agent.id && m.content.present? }
    assert opus_msgs.any?, "Opus should have responded"
    opus_msg = opus_msgs.last

    # Check GPT response (thinking enabled)
    gpt_msgs = agent_messages.select { |m| m.agent_id == gpt_agent.id && m.content.present? }
    assert gpt_msgs.any?, "GPT should have responded"
    gpt_msg = gpt_msgs.last

    # Check Grok response (thinking NOT enabled)
    grok_msgs = agent_messages.select { |m| m.agent_id == grok_agent.id && m.content.present? }
    assert grok_msgs.any?, "Grok should have responded"
    grok_msg = grok_msgs.last
    # Grok should NOT have thinking since its model doesn't support it
    assert grok_msg.thinking.blank?, "Grok should not have thinking content"

    # Verify memories were created
    opus_memories = opus_agent.memories.reload
    assert opus_memories.any?, "Opus should have saved a memory"

    gpt_memories = gpt_agent.memories.reload
    assert gpt_memories.any?, "GPT should have saved a memory"

    grok_memories = grok_agent.memories.reload
    assert grok_memories.any?, "Grok should have saved a memory"
  end

  test "legacy unsigned assistant turn replays without thinking; new turn keeps thinking enabled" do
    opus_agent = @account.agents.create!(
      name: "Claude Opus",
      model_id: "anthropic/claude-opus-4.5",
      system_prompt: "You are Claude Opus.",
      thinking_enabled: true,
      thinking_budget: 5000
    )

    chat = @account.chats.new(
      model_id: "openai/gpt-4o",
      manual_responses: true,
      title: "Legacy Replay Test"
    )
    chat.agents = [ opus_agent ]
    chat.save!

    chat.messages.create!(role: "user", user: @user, content: "Hello!")

    chat.messages.create!(
      role: "assistant",
      agent: opus_agent,
      content: "Hello! I'm Claude Opus from the past.",
      thinking: "Old thinking text without a signature."
    )

    context = chat.build_context_for_agent(opus_agent, thinking_enabled: true, provider: :anthropic)
    legacy_msg = context.find { |m| m[:role] == "assistant" && m[:content].to_s.include?("from the past") }
    assert_not_nil legacy_msg, "Opus's legacy message should be in context"
    assert_nil legacy_msg[:thinking], "Legacy unsigned thinking must not be replayed"
    assert_nil legacy_msg[:thinking_signature]
  end

  test "signed Anthropic thinking is preserved across replay" do
    opus_agent = @account.agents.create!(
      name: "Claude Opus",
      model_id: "anthropic/claude-opus-4.5",
      system_prompt: "You are Claude Opus.",
      thinking_enabled: true,
      thinking_budget: 5000
    )

    chat = @account.chats.new(
      model_id: "openai/gpt-4o",
      manual_responses: true,
      title: "Thinking Preservation Test"
    )
    chat.agents = [ opus_agent ]
    chat.save!

    chat.messages.create!(role: "user", user: @user, content: "Hello!")

    chat.messages.create!(
      role: "assistant",
      agent: opus_agent,
      content: "Hello! I'm Claude Opus.",
      thinking: "This is my original thinking content.",
      replay_payload: {
        "provider" => "anthropic",
        "thinking" => { "text" => "This is my original thinking content.", "signature" => "sig123" }
      }
    )

    context = chat.build_context_for_agent(opus_agent, thinking_enabled: true, provider: :anthropic)
    opus_context_msg = context.find { |m| m[:content].to_s.include?("I'm Claude Opus") }
    assert_not_nil opus_context_msg

    assert_kind_of RubyLLM::Thinking, opus_context_msg[:thinking]
    assert_equal "This is my original thinking content.", opus_context_msg[:thinking].text
    assert_equal "sig123", opus_context_msg[:thinking].signature
  end

  test "thinking agent can join conversation with non-thinking agent messages" do
    # This tests that a thinking-enabled agent can join a conversation where
    # other agents (without thinking) have already responded. Since other agents'
    # messages appear as "user" role in the thinking agent's context, they don't
    # need thinking blocks.

    # Create a non-thinking agent first
    grok_agent = @account.agents.create!(
      name: "Grok",
      model_id: "x-ai/grok-4",
      system_prompt: "You are Grok. Be brief.",
      thinking_enabled: false,
      enabled_tools: [ "SaveMemoryTool" ]
    )

    # Create a thinking agent
    opus_agent = @account.agents.create!(
      name: "Claude Opus",
      model_id: "anthropic/claude-opus-4.5",
      system_prompt: "You are Claude Opus. Use the save_memory tool to remember things. Be brief.",
      thinking_enabled: true,
      thinking_budget: 5000,
      enabled_tools: [ "SaveMemoryTool" ]
    )

    # Create chat with both agents
    chat = @account.chats.new(
      model_id: "openai/gpt-4o",
      manual_responses: true,
      title: "Thinking Continuation Test"
    )
    chat.agents = [ grok_agent, opus_agent ]
    chat.save!

    VCR.use_cassette("thinking/continuation_with_placeholder", record: :new_episodes, match_requests_on: [ :method, :uri ]) do
      # User message
      chat.messages.create!(
        role: "user",
        user: @user,
        content: "Hello everyone!"
      )

      # Grok responds first (no thinking)
      ManualAgentResponseJob.perform_now(chat, grok_agent)

      grok_msg = chat.messages.where(role: "assistant", agent: grok_agent).last
      assert_not_nil grok_msg
      assert grok_msg.thinking.blank?, "Grok should not have thinking"

      # Other agents' messages replay as user-shaped, so they don't affect Opus's thinking.

      # User asks Opus to remember something
      chat.messages.create!(
        role: "user",
        user: @user,
        content: "Claude, please use your save_memory tool to remember that 'Grok said hello first'."
      )

      # Opus responds (with thinking enabled)
      # This works because Grok's messages appear as "user" role in Opus's context
      ManualAgentResponseJob.perform_now(chat, opus_agent)

      opus_msg = chat.messages.where(role: "assistant", agent: opus_agent).last
      assert_not_nil opus_msg
      assert opus_msg.content.present?, "Opus should have responded"

      # Verify memory was saved
      opus_memories = opus_agent.memories.reload
      assert opus_memories.any?, "Opus should have saved a memory"
    end
  end

end
