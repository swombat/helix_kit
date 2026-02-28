require "test_helper"

class ChatThinkingTest < ActiveSupport::TestCase

  test "supports_thinking? returns true for capable models" do
    assert Chat.supports_thinking?("anthropic/claude-opus-4.5")
    assert Chat.supports_thinking?("anthropic/claude-sonnet-4.5")
    assert Chat.supports_thinking?("anthropic/claude-opus-4")
    assert Chat.supports_thinking?("anthropic/claude-sonnet-4")
    assert Chat.supports_thinking?("anthropic/claude-3.7-sonnet")
    assert Chat.supports_thinking?("openai/gpt-5.2")
    assert Chat.supports_thinking?("openai/gpt-5.1")
    assert Chat.supports_thinking?("openai/gpt-5")
    assert Chat.supports_thinking?("google/gemini-3-pro-preview")
  end

  test "supports_thinking? returns false for non-capable models" do
    refute Chat.supports_thinking?("anthropic/claude-3.5-sonnet")
    refute Chat.supports_thinking?("anthropic/claude-3-opus")
    refute Chat.supports_thinking?("anthropic/claude-haiku-4.5")
    refute Chat.supports_thinking?("openai/gpt-4o")
    refute Chat.supports_thinking?("openai/gpt-4o-mini")
    refute Chat.supports_thinking?("openai/gpt-5-mini")
    refute Chat.supports_thinking?("openai/gpt-5-nano")
    refute Chat.supports_thinking?("google/gemini-2.5-pro")
  end

  test "supports_thinking? returns false for unknown models" do
    refute Chat.supports_thinking?("unknown/model")
    refute Chat.supports_thinking?("nonexistent/gpt-10")
    refute Chat.supports_thinking?(nil)
  end

  test "requires_direct_api_for_thinking? returns true for Claude 4+ models" do
    assert Chat.requires_direct_api_for_thinking?("anthropic/claude-opus-4.5")
    assert Chat.requires_direct_api_for_thinking?("anthropic/claude-sonnet-4.5")
    assert Chat.requires_direct_api_for_thinking?("anthropic/claude-opus-4")
    assert Chat.requires_direct_api_for_thinking?("anthropic/claude-sonnet-4")
  end

  test "requires_direct_api_for_thinking? returns false for non-Claude 4 models" do
    refute Chat.requires_direct_api_for_thinking?("anthropic/claude-3.7-sonnet")
    refute Chat.requires_direct_api_for_thinking?("anthropic/claude-3.5-sonnet")
    refute Chat.requires_direct_api_for_thinking?("openai/gpt-5.2")
    refute Chat.requires_direct_api_for_thinking?("openai/gpt-5")
    refute Chat.requires_direct_api_for_thinking?("google/gemini-3-pro-preview")
  end

  test "requires_direct_api_for_thinking? returns false for unknown models" do
    refute Chat.requires_direct_api_for_thinking?("unknown/model")
    refute Chat.requires_direct_api_for_thinking?(nil)
  end

  test "provider_model_id returns correct Anthropic model ID for Claude 4.5 Opus" do
    assert_equal "claude-opus-4-5-20251101", Chat.provider_model_id("anthropic/claude-opus-4.5")
  end

  test "provider_model_id returns correct Anthropic model ID for Claude 4.5 Sonnet" do
    assert_equal "claude-sonnet-4-5-20250929", Chat.provider_model_id("anthropic/claude-sonnet-4.5")
  end

  test "provider_model_id returns correct Anthropic model ID for Claude 4 Opus" do
    assert_equal "claude-opus-4-20250514", Chat.provider_model_id("anthropic/claude-opus-4")
  end

  test "provider_model_id returns correct Anthropic model ID for Claude 4 Sonnet" do
    assert_equal "claude-sonnet-4-20250514", Chat.provider_model_id("anthropic/claude-sonnet-4")
  end

  test "provider_model_id falls back to stripping provider prefix for OpenAI models" do
    assert_equal "gpt-5.2", Chat.provider_model_id("openai/gpt-5.2")
    assert_equal "gpt-5", Chat.provider_model_id("openai/gpt-5")
    assert_equal "gpt-4o", Chat.provider_model_id("openai/gpt-4o")
  end

  test "provider_model_id falls back to stripping provider prefix for Google models" do
    assert_equal "gemini-3-pro-preview", Chat.provider_model_id("google/gemini-3-pro-preview")
    assert_equal "gemini-2.5-pro", Chat.provider_model_id("google/gemini-2.5-pro")
  end

  test "provider_model_id handles models without provider prefix" do
    assert_equal "gpt-5", Chat.provider_model_id("gpt-5")
    assert_equal "claude-opus-4", Chat.provider_model_id("claude-opus-4")
  end

  test "model_config returns correct config for known models" do
    config = Chat.model_config("anthropic/claude-opus-4.5")
    assert_not_nil config
    assert_equal "anthropic/claude-opus-4.5", config[:model_id]
    assert_equal "Claude Opus 4.5", config[:label]
    assert_equal "Anthropic", config[:group]
    assert_equal true, config.dig(:thinking, :supported)
    assert_equal true, config.dig(:thinking, :requires_direct_api)
    assert_equal "claude-opus-4-5-20251101", config[:provider_model_id]
  end

  test "model_config returns correct config for models without thinking" do
    config = Chat.model_config("anthropic/claude-3.5-sonnet")
    assert_not_nil config
    assert_equal "anthropic/claude-3.5-sonnet", config[:model_id]
    assert_equal "Claude 3.5 Sonnet", config[:label]
    assert_nil config.dig(:thinking, :supported)
  end

  test "model_config returns nil for unknown models" do
    assert_nil Chat.model_config("unknown/model")
    assert_nil Chat.model_config("fake/gpt-100")
    assert_nil Chat.model_config(nil)
  end

  test "MODELS constant includes thinking metadata for all thinking-capable models" do
    thinking_models = Chat::MODELS.select { |m| m.dig(:thinking, :supported) == true }

    # Verify we have thinking models
    assert thinking_models.any?, "Should have at least one thinking-capable model"

    # Verify all Claude 4+ models have requires_direct_api flag
    claude_4_models = thinking_models.select { |m| m[:model_id].match?(/claude-(opus|sonnet)-4/) }
    claude_4_models.each do |model|
      assert_equal true, model.dig(:thinking, :requires_direct_api),
                   "#{model[:model_id]} should require direct API"
      assert model[:provider_model_id].present?,
                   "#{model[:model_id]} should have provider_model_id"
    end
  end

  test "MODELS constant does not include thinking metadata for non-capable models" do
    non_thinking_models = Chat::MODELS.reject { |m| m.dig(:thinking, :supported) == true }

    # Verify we have non-thinking models
    assert non_thinking_models.any?, "Should have models without thinking"

    # Verify none have requires_direct_api flag
    non_thinking_models.each do |model|
      refute_equal true, model.dig(:thinking, :requires_direct_api),
                   "#{model[:model_id]} should not require direct API"
    end
  end

end
