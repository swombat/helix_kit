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
          cache_control: { type: "ephemeral" }
        }
      ],
      messages.first[:content].value
    )
    assert_equal "Current time: now", messages.second[:content]
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

end
