require "test_helper"

class LlmPromptCachePolicyTest < ActiveSupport::TestCase

  test "marks only the stable Anthropic system prefix for caching" do
    messages = LlmPromptCachePolicy.system_messages(
      stable: "Stable identity",
      dynamic: "Current time: now",
      provider: :anthropic
    )

    assert_equal 2, messages.length
    assert_instance_of RubyLLM::Content::Raw, messages.first[:content]
    assert_equal(
      [
        {
          type: "text",
          text: "Stable identity",
          cache_control: { type: "ephemeral", ttl: "1h" }
        }
      ],
      messages.first[:content].value
    )
    assert_equal "Current time: now", messages.second[:content]
  end

  test "uses the configured Anthropic cache TTL verbatim" do
    messages = with_env("HELIX_ANTHROPIC_CACHE_TTL" => "5m") do
      LlmPromptCachePolicy.system_messages(
        stable: "Stable identity",
        dynamic: "",
        provider: :anthropic
      )
    end

    assert_equal(
      { type: "ephemeral", ttl: "5m" },
      messages.first[:content].value.first[:cache_control]
    )
  end

  test "marks the last text-only Anthropic transcript message for caching" do
    transcript = [
      { role: "user", content: "First question" },
      { role: "assistant", content: "First answer", thinking: "private" },
      { role: "user", content: "Second question" }
    ]

    messages = LlmPromptCachePolicy.transcript_messages(
      messages: transcript,
      provider: :anthropic
    )

    assert_equal "First question", messages.first[:content]
    assert_equal "First answer", messages.second[:content]
    assert_equal "private", messages.second[:thinking]
    assert_instance_of RubyLLM::Content::Raw, messages.last[:content]
    assert_equal(
      [
        {
          type: "text",
          text: "Second question",
          cache_control: { type: "ephemeral", ttl: "1h" }
        }
      ],
      messages.last[:content].value
    )
    assert_equal transcript.first(2), messages.first(2)
    assert_equal "Second question", transcript.last[:content]
  end

  test "falls back to the nearest preceding text-only message when the tail has attachments" do
    multipart_content = RubyLLM::Content.new("See the attached document")
    transcript = [
      { role: "user", content: "Cache this text" },
      { role: "user", content: multipart_content }
    ]

    messages = LlmPromptCachePolicy.transcript_messages(
      messages: transcript,
      provider: :anthropic
    )

    assert_instance_of RubyLLM::Content::Raw, messages.first[:content]
    assert_same multipart_content, messages.last[:content]
    assert_equal "Cache this text", transcript.first[:content]
  end

  test "leaves an Anthropic transcript without text-only content unchanged" do
    content = RubyLLM::Content.new("A document")
    transcript = [ { role: "user", content: content } ]

    messages = LlmPromptCachePolicy.transcript_messages(
      messages: transcript,
      provider: :anthropic
    )

    assert_same transcript, messages
  end

  test "keeps automatic-cache providers on one plain prefix-stable message" do
    %i[openai gemini xai openrouter].each do |provider|
      messages = LlmPromptCachePolicy.system_messages(
        stable: "Stable identity",
        dynamic: "Current time: now",
        provider: provider
      )

      assert_equal 1, messages.length, provider
      assert_equal "Stable identity\n\nCurrent time: now", messages.first[:content], provider
    end
  end

  test "leaves non-Anthropic transcript messages byte-for-byte unchanged" do
    %i[openai gemini xai openrouter].each do |provider|
      transcript = [
        { role: "user", content: "Question" },
        { role: "assistant", content: "Answer", tool_calls: [ { id: "tool-1" } ] }
      ]

      messages = LlmPromptCachePolicy.transcript_messages(
        messages: transcript,
        provider: provider
      )

      assert_same transcript, messages, provider
      assert_same transcript.first, messages.first, provider
      assert_same transcript.last, messages.last, provider
    end
  end

  private

  def with_env(values)
    original = values.to_h { |key, _| [ key, ENV[key] ] }
    values.each { |key, value| ENV[key] = value }
    yield
  ensure
    original.each { |key, value| ENV[key] = value }
  end

end
