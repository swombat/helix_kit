require "test_helper"
require "vcr"

class RubyLlmProviderUpgradeTest < ActiveSupport::TestCase

  PROVIDERS = {
    anthropic: {
      model: "claude-opus-4-6",
      cassette: "ruby_llm_upgrade/anthropic",
      expected_input: 200,
      expected_cache_read: 0,
      expected_cache_write: 1_000
    },
    openai: {
      model: "gpt-5.4",
      cassette: "ruby_llm_upgrade/openai",
      expected_input: 200,
      expected_cache_read: 1_000,
      expected_cache_write: 0
    },
    gemini: {
      model: "gemini-3.1-pro-preview",
      cassette: "ruby_llm_upgrade/gemini",
      expected_input: 200,
      expected_cache_read: 1_000,
      expected_cache_write: nil
    },
    xai: {
      model: "grok-4.5",
      cassette: "ruby_llm_upgrade/xai",
      expected_input: 200,
      expected_cache_read: 1_000,
      expected_cache_write: 0
    }
  }.freeze

  PROVIDERS.each do |provider, config|
    test "RubyLLM 1.16 completes a cached-prefix request with #{provider}" do
      response = VCR.use_cassette(config[:cassette]) do
        chat = RubyLLM.chat(
          model: config[:model],
          provider: provider,
          assume_model_exists: true
        )
        LlmPromptCachePolicy.system_messages(
          stable: "Stable identity",
          dynamic: "Dynamic context",
          provider: provider
        ).each { |message| chat.add_message(message) }

        chat.ask("Reply with ok")
      end

      assert_equal "ok", response.content
      assert_equal config[:expected_input], response.input_tokens
      assert_equal config[:expected_cache_read], response.cache_read_tokens
      if config[:expected_cache_write].nil?
        assert_nil response.cache_write_tokens
      else
        assert_equal config[:expected_cache_write], response.cache_write_tokens
      end
    end
  end

end
