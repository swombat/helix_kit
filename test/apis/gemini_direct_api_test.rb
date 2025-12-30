require "test_helper"

# Test for direct Gemini API access (not via OpenRouter)
# This tests the thought_signature handling required for Gemini 2.5+ and 3 tool calling
class GeminiDirectApiTest < ActiveSupport::TestCase

  # Simple test tool for verifying tool calling works
  class EchoTool < RubyLLM::Tool

    description "Echoes back the provided message"
    param :message, type: "string", desc: "The message to echo back"

    def execute(message:)
      { echoed: message, timestamp: Time.current.iso8601 }
    end

  end

  class CalculatorTool < RubyLLM::Tool

    description "Performs basic arithmetic operations"
    param :operation, type: "string", desc: "The operation: add, subtract, multiply, divide"
    param :a, type: "number", desc: "First number"
    param :b, type: "number", desc: "Second number"

    def execute(operation:, a:, b:)
      result = case operation
      when "add" then a + b
      when "subtract" then a - b
      when "multiply" then a * b
      when "divide" then b.zero? ? "Error: Division by zero" : a / b.to_f
      else "Unknown operation"
      end
      { result: result, operation: operation, a: a, b: b }
    end

  end

  setup do
    # Skip if Gemini API key not configured
    gemini_key = Rails.application.credentials.dig(:ai, :gemini, :api_token)
    skip "Gemini API key not configured" if gemini_key.blank? || gemini_key.start_with?("<")
  end

  test "basic response from gemini-3-pro-preview without tools" do
    VCR.use_cassette("gemini_direct_basic_response") do
      llm = RubyLLM.chat(
        model: "gemini-3-pro-preview",
        provider: :gemini,
        assume_model_exists: true
      )

      response = llm.ask("What is 2 + 2? Reply with just the number.")

      assert response.content.present?
      assert_includes response.content, "4"
    end
  end

  test "gemini-3-pro-preview with tool calling" do
    VCR.use_cassette("gemini_direct_tool_calling") do
      llm = RubyLLM.chat(
        model: "gemini-3-pro-preview",
        provider: :gemini,
        assume_model_exists: true
      )

      llm = llm.with_tool(CalculatorTool)

      tool_called = false
      llm.on_tool_call { |tc| tool_called = true }

      response = llm.ask("What is 15 multiplied by 7? Use the calculator tool.")

      assert tool_called, "Expected tool to be called"
      assert response.content.present?
      # 15 * 7 = 105
      assert_includes response.content, "105"
    end
  end

  test "gemini-2.5-pro with tool calling" do
    VCR.use_cassette("gemini_25_pro_tool_calling") do
      llm = RubyLLM.chat(
        model: "gemini-2.5-pro",
        provider: :gemini,
        assume_model_exists: true
      )

      llm = llm.with_tool(EchoTool)

      tool_called = false
      tool_call_name = nil
      llm.on_tool_call { |tc| tool_called = true; tool_call_name = tc.name }

      response = llm.ask("Please echo the message 'Hello from Gemini test'")

      assert tool_called, "Expected tool to be called"
      assert_includes tool_call_name, "echo", "Expected tool name to include 'echo'"
      assert response.content.present?
    end
  end

  test "gemini model IDs are normalized correctly" do
    # Test the SelectsLlmProvider concern
    job = ManualAgentResponseJob.new

    config = job.send(:llm_provider_for, "google/gemini-3-pro-preview")

    # If Gemini is enabled, should use direct provider with normalized ID
    # If not enabled, should use OpenRouter with original ID
    if job.send(:gemini_direct_access_enabled?)
      assert_equal :gemini, config[:provider]
      assert_equal "gemini-3-pro-preview", config[:model_id]
    else
      assert_equal :openrouter, config[:provider]
      assert_equal "google/gemini-3-pro-preview", config[:model_id]
    end
  end

  test "non-gemini models use openrouter" do
    job = ManualAgentResponseJob.new

    config = job.send(:llm_provider_for, "anthropic/claude-3.5-sonnet")

    assert_equal :openrouter, config[:provider]
    assert_equal "anthropic/claude-3.5-sonnet", config[:model_id]
  end

end
