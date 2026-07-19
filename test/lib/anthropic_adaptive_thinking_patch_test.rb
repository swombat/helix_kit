require "test_helper"
require "ostruct"

class AnthropicAdaptiveThinkingPatchTest < ActiveSupport::TestCase

  setup do
    @provider = RubyLLM::Providers::Anthropic.allocate
  end

  test "uses adaptive thinking for known adaptive models without registry metadata" do
    model = model_without_reasoning_metadata("claude-opus-4-7")
    thinking = RubyLLM::Thinking::Config.new(budget: 8_000)

    payload = @provider.send(:build_thinking_payload, thinking, model)

    assert_equal({ type: "adaptive" }, payload[:thinking])
    assert_equal({ effort: "medium" }, payload[:output_config])
  end

  test "uses budget thinking for older models without registry metadata" do
    model = model_without_reasoning_metadata("claude-opus-4-5-20251101")
    thinking = RubyLLM::Thinking::Config.new(budget: 8_000)

    payload = @provider.send(:build_thinking_payload, thinking, model)

    assert_equal({ type: "enabled", budget_tokens: 8_000 }, payload[:thinking])
  end

  private

  def model_without_reasoning_metadata(id)
    Struct.new(:id) do
      def reasoning_option(_type)
        nil
      end
    end.new(id)
  end

end
