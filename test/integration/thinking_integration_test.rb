require "test_helper"
require "vcr"

class ThinkingIntegrationTest < ActiveSupport::TestCase

  # === Extended Thinking Integration Tests ===
  # These tests verify that the Extended Thinking feature works correctly
  # with real API calls recorded via VCR.
  #
  # IMPORTANT: These tests are disabled by default (using skip_ prefix)
  # To enable and record new cassettes:
  # 1. Ensure valid Anthropic API key is configured in Rails credentials
  # 2. Change skip_test to test and run individually
  # 3. Commit the generated cassettes to test/vcr_cassettes/thinking/

  setup do
    @user = User.create!(
      email_address: "thinking-#{SecureRandom.hex(4)}@example.com",
      password: "password123"
    )
    @user.profile.update!(first_name: "Test", last_name: "User")
    @account = @user.personal_account
  end

  # Test that thinking configuration is properly set up
  test "thinking configuration is present in model metadata" do
    # Verify Claude 4.5 models have thinking metadata
    opus_config = Chat.model_config("anthropic/claude-opus-4.5")
    assert_not_nil opus_config
    assert_equal true, opus_config.dig(:thinking, :supported)
    assert_equal true, opus_config.dig(:thinking, :requires_direct_api)
    assert_equal "claude-opus-4-5-20251101", opus_config.dig(:thinking, :provider_model_id)

    sonnet_config = Chat.model_config("anthropic/claude-sonnet-4.5")
    assert_not_nil sonnet_config
    assert_equal true, sonnet_config.dig(:thinking, :supported)
    assert_equal true, sonnet_config.dig(:thinking, :requires_direct_api)
  end

  # Test that agents with thinking enabled report correctly
  test "agent with thinking enabled and supported model uses thinking" do
    agent = @account.agents.create!(
      name: "Thinking Agent",
      model_id: "anthropic/claude-opus-4.5",
      thinking_enabled: true,
      thinking_budget: 15000
    )

    assert agent.uses_thinking?
    assert Chat.supports_thinking?(agent.model_id)
    assert Chat.requires_direct_api_for_thinking?(agent.model_id)
  end

  # Test that messages can store thinking content
  test "message can store and retrieve thinking content" do
    chat = @account.chats.create!(model_id: "openai/gpt-4o")
    message = chat.messages.create!(
      role: "assistant",
      content: "Here is my response.",
      thinking: "Let me think about this carefully. I should consider multiple approaches."
    )

    assert_equal "Here is my response.", message.content
    assert_equal "Let me think about this carefully. I should consider multiple approaches.", message.thinking
    assert_not_nil message.thinking_preview
    assert message.thinking_preview.length <= 80
  end

  # === VCR-Based API Tests (Disabled by Default) ===

  # This test would record a VCR cassette with actual Anthropic API call
  # using extended thinking. Disabled by default because it requires:
  # - Valid Anthropic API key in credentials
  # - Real API call to be made
  # - Manual execution to record cassette
  def skip_test_anthropic_claude_opus_4_5_with_thinking
    # Create an agent with thinking enabled
    agent = @account.agents.create!(
      name: "Deep Thinker",
      model_id: "anthropic/claude-opus-4.5",
      system_prompt: "You are a thoughtful assistant who explains your reasoning.",
      thinking_enabled: true,
      thinking_budget: 10000
    )

    # Create a group chat with manual responses
    chat = @account.chats.new(
      model_id: "openai/gpt-4o", # Not used for group chats
      manual_responses: true
    )
    chat.agents << agent
    chat.save!

    # Add a user message
    user_message = chat.messages.create!(
      role: "user",
      user: @user,
      content: "What is the capital of France? Think through your answer."
    )

    # Record the API interaction with VCR
    VCR.use_cassette("thinking/claude_opus_4_5_with_thinking") do
      # Trigger agent response
      ManualAgentResponseJob.perform_now(chat, agent)
    end

    # Verify thinking was captured
    assistant_message = chat.messages.where(role: "assistant", agent: agent).last
    assert_not_nil assistant_message
    assert assistant_message.content.present?

    # Verify thinking content was captured
    assert assistant_message.thinking.present?, "Thinking content should be captured"
    assert assistant_message.thinking.length > 0

    # Verify thinking preview is generated
    assert assistant_message.thinking_preview.present?
    assert assistant_message.thinking_preview.length <= 80
  end

  # Test thinking with Claude Sonnet 4.5
  def skip_test_anthropic_claude_sonnet_4_5_with_thinking
    agent = @account.agents.create!(
      name: "Sonnet Thinker",
      model_id: "anthropic/claude-sonnet-4.5",
      system_prompt: "You are a helpful assistant.",
      thinking_enabled: true,
      thinking_budget: 8000
    )

    chat = @account.chats.new(
      model_id: "openai/gpt-4o",
      manual_responses: true
    )
    chat.agents << agent
    chat.save!

    chat.messages.create!(
      role: "user",
      user: @user,
      content: "Solve this: 2 + 2 = ?"
    )

    VCR.use_cassette("thinking/claude_sonnet_4_5_with_thinking") do
      ManualAgentResponseJob.perform_now(chat, agent)
    end

    assistant_message = chat.messages.where(role: "assistant", agent: agent).last
    assert_not_nil assistant_message
    assert assistant_message.content.present?
    assert assistant_message.thinking.present?, "Thinking content should be captured"
  end

  # Test that non-thinking models don't capture thinking
  def skip_test_claude_3_5_without_thinking
    agent = @account.agents.create!(
      name: "Non-Thinking Agent",
      model_id: "anthropic/claude-3.5-sonnet",
      thinking_enabled: true # Enabled, but model doesn't support it
    )

    refute agent.uses_thinking?, "Claude 3.5 should not use thinking even when enabled"

    chat = @account.chats.new(
      model_id: "openai/gpt-4o",
      manual_responses: true
    )
    chat.agents << agent
    chat.save!

    chat.messages.create!(
      role: "user",
      user: @user,
      content: "Hello"
    )

    VCR.use_cassette("thinking/claude_3_5_without_thinking") do
      ManualAgentResponseJob.perform_now(chat, agent)
    end

    assistant_message = chat.messages.where(role: "assistant", agent: agent).last
    assert_not_nil assistant_message
    assert assistant_message.content.present?
    assert assistant_message.thinking.blank?, "Non-thinking model should not capture thinking"
  end

  # Test thinking budget validation
  test "thinking budget is validated on agent" do
    agent = @account.agents.build(
      name: "Budget Test Agent",
      model_id: "anthropic/claude-opus-4.5",
      thinking_enabled: true
    )

    # Too low
    agent.thinking_budget = 500
    refute agent.valid?
    assert agent.errors[:thinking_budget].any?

    # Too high
    agent.thinking_budget = 60000
    refute agent.valid?
    assert agent.errors[:thinking_budget].any?

    # Just right
    agent.thinking_budget = 10000
    agent.valid?
    refute agent.errors[:thinking_budget].any?
  end

  # Test that thinking settings are included in agent JSON
  test "agent json includes thinking settings" do
    agent = @account.agents.create!(
      name: "JSON Test Agent",
      model_id: "anthropic/claude-opus-4.5",
      thinking_enabled: true,
      thinking_budget: 12000
    )

    json = agent.as_json
    assert_equal true, json["thinking_enabled"]
    assert_equal 12000, json["thinking_budget"]
  end

  # Test that message streaming methods work
  test "message stream_thinking updates thinking content" do
    chat = @account.chats.create!(model_id: "openai/gpt-4o")
    message = chat.messages.create!(
      role: "assistant",
      content: "",
      thinking: ""
    )

    # Stream thinking in chunks
    message.stream_thinking("First thought. ")
    message.reload
    assert_equal "First thought. ", message.thinking

    message.stream_thinking("Second thought.")
    message.reload
    assert_equal "First thought. Second thought.", message.thinking
  end

  # Test that provider routing logic works correctly
  test "llm provider routing for thinking models" do
    # This tests the SelectsLlmProvider concern logic
    # We can't easily test the actual routing without mocking,
    # but we can verify the class methods work correctly

    # Claude 4+ with thinking should route to Anthropic direct
    assert Chat.requires_direct_api_for_thinking?("anthropic/claude-opus-4.5")
    assert_equal "claude-opus-4-5-20251101", Chat.provider_model_id("anthropic/claude-opus-4.5")

    # GPT-5 with thinking should NOT require direct API (goes through OpenRouter)
    assert Chat.supports_thinking?("openai/gpt-5")
    refute Chat.requires_direct_api_for_thinking?("openai/gpt-5")
  end

end
