require "test_helper"
require "support/vcr_setup"

# This test validates the Prompt class functionality with VCR recorded API calls for Claude Sonnet 4 model
# VCR records API responses in test/vcr_cassettes/ directory
# When a test runs:
# - If a cassette exists, it will replay the recorded responses
# - If no cassette exists, it will make real API calls and record them
class ClaudeSonnetPromptTest < ActiveSupport::TestCase

  class TestPrompt < Prompt

    def initialize(model: "anthropic/claude-sonnet-4", system: "You are a helpful assistant.", user: "Hello, world!")
      super(model: model, template: nil) # No template needed

      @args = {
        system: system,
        user: user
      }
    end

    def render(**args)
      args = @args if args.empty?

      {
        model: @model,
        system: args[:system],
        user: args[:user]
      }
    end

  end

  setup do
    @account = Account.first
  end

  test "executes to string with Claude Sonnet 4 model" do
    VCR.use_cassette("prompt/execute_to_string_claude_sonnet") do
      # Create a test prompt
      test_prompt = TestPrompt.new(
        model: "anthropic/claude-sonnet-4",
        system: "You are a helpful assistant.",
        user: "What is the capital of Portugal?"
      )

      # Test non-streaming response
      response = test_prompt.execute_to_string
      assert response.present?

      # The Prompt class should abstract away the differences in response formats
      # Just check the response for the expected content
      text = response.to_s
      assert_includes text.downcase, "lisbon", "Expected response to contain 'lisbon'"
    end
  end

  test "executes to json with Claude Sonnet model" do
    VCR.use_cassette("prompt/execute_to_json_claude_sonnet") do
      test_prompt = TestPrompt.new(
        model: "anthropic/claude-sonnet-4",
        system: "You are a helpful assistant. Always respond with valid JSON. Return a JSON object with a 'countries' array containing objects with 'country' and 'capital' fields.",
        user: "List 3 African countries and their capitals."
      )

      response = test_prompt.execute_to_json

      assert response.present?
    end
  end

  test "executes with output to PromptOutput object using Claude Sonnet 4 model" do
    VCR.use_cassette("prompt/execute_to_prompt_output_claude_sonnet") do
      # Create a test prompt
      test_prompt = TestPrompt.new(
        model: "anthropic/claude-sonnet-4",
        system: "You are a helpful assistant.",
        user: "What is the capital of Australia?"
      )

      # Create a PromptOutput record
      prompt_output = PromptOutput.create(account: @account)
      assert prompt_output.persisted?

      # Execute with output to PromptOutput
      response = test_prompt.execute(
        output_class: "PromptOutput",
        output_id: prompt_output.id,
        output_property: :output
      )

      # Refresh from database
      prompt_output.reload

      # Verify text content was saved to the output field
      assert prompt_output.output.present?, "Expected PromptOutput's output field to be populated"
      assert_includes prompt_output.output.downcase, "canberra", "Expected response to contain 'canberra'"

      # Verify response is the accumulated text
      assert_kind_of String, response
      assert response.present?, "Expected response to be present"
    end
  end

end
