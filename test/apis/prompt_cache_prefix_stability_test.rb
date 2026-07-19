require "test_helper"
require "vcr"

class PromptCachePrefixStabilityTest < ActiveSupport::TestCase

  PROVIDERS = {
    anthropic: {
      model: "claude-opus-4-6",
      cassette: "prompt_cache_prefix_stability/anthropic"
    },
    openai: {
      model: "gpt-5.4",
      cassette: "prompt_cache_prefix_stability/openai"
    }
  }.freeze

  REQUEST_SHAPE_PROVIDERS = {
    gemini: {
      model: "gemini-3.1-pro-preview",
      cassette: "prompt_cache_prefix_stability/gemini_request_shape"
    },
    xai: {
      model: "grok-4.5",
      cassette: "prompt_cache_prefix_stability/xai_request_shape"
    }
  }.freeze

  PROVIDERS.each do |provider, config|
    test "#{provider} reuses the stable system and transcript when the tail envelope changes" do
      first, second = VCR.use_cassette(config[:cassette]) do
        [
          complete_request(provider:, model: config[:model], envelope: "Activation minute: 10:01"),
          complete_request(provider:, model: config[:model], envelope: "Activation minute: 10:02")
        ]
      end

      first_total_input = [
        first.input_tokens,
        first.cache_read_tokens,
        first.cache_write_tokens
      ].compact.sum

      assert_operator first_total_input, :>, 1_024
      assert_operator second.cache_read_tokens.to_i, :>=, first_total_input * 0.9
      assert_equal "OK", second.content.strip.upcase
    end
  end

  test "Anthropic reuses the prior transcript prefix when a completed turn is appended" do
    first, second = VCR.use_cassette("prompt_cache_prefix_stability/anthropic_appended_turn") do
      base_transcript = [
        { role: "user", content: long_text("question") },
        { role: "assistant", content: long_text("answer") }
      ]

      [
        complete_request(
          provider: :anthropic,
          model: "claude-opus-4-6",
          envelope: "Activation minute: 10:01",
          transcript: base_transcript,
          newest_human: "First current turn. Reply with only OK."
        ),
        complete_request(
          provider: :anthropic,
          model: "claude-opus-4-6",
          envelope: "Activation minute: 10:02",
          transcript: base_transcript + [
            { role: "user", content: "First current turn. Reply with only OK." },
            { role: "assistant", content: "OK" }
          ],
          newest_human: "Second current turn. Reply with only OK."
        )
      ]
    end

    first_total_input = [
      first.input_tokens,
      first.cache_read_tokens,
      first.cache_write_tokens
    ].compact.sum

    assert_operator first_total_input, :>, 1_024
    assert_operator second.cache_read_tokens.to_i, :>=, first_total_input * 0.9
    assert_equal "OK", second.content.strip.upcase
  end

  REQUEST_SHAPE_PROVIDERS.each do |provider, config|
    test "#{provider} accepts the transcript, synthetic envelope, and newest human message shape" do
      response = VCR.use_cassette(config[:cassette]) do
        complete_request(
          provider:,
          model: config[:model],
          envelope: "Activation minute: 10:03",
          long_prefix: false
        )
      end

      assert_match(/\AOK[.!]?\z/i, response.content.strip)
      assert_operator response.input_tokens.to_i, :>, 0
    end
  end

  private

  def complete_request(provider:, model:, envelope:, long_prefix: true, transcript: nil, newest_human: "Reply with only OK.")
    chat = RubyLLM.chat(model:, provider:, assume_model_exists: true)
    stable = long_prefix ? long_text("stable") : "Stable identity for request-shape verification."
    transcript ||= [
      { role: "user", content: long_prefix ? long_text("question") : "Earlier question." },
      { role: "assistant", content: long_prefix ? long_text("answer") : "Earlier answer." }
    ]

    LlmPromptCachePolicy.system_messages(
      stable: stable,
      dynamic: "",
      provider:
    ).each { |message| chat.add_message(message) }

    LlmPromptCachePolicy.transcript_messages(
      messages: transcript,
      provider:
    ).each { |message| chat.add_message(message) }

    chat.add_message(
      role: "user",
      content: "<helixkit_context>\n#{envelope}\n</helixkit_context>"
    )
    chat.add_message(role: "user", content: newest_human)
    chat.complete
  end

  def long_text(label)
    @long_text ||= {}
    @long_text[label] ||= 300.times.map do |index|
      "#{label}-prefix-stability-token-#{index}"
    end.join(" ")
  end

end
