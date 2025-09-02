require "test_helper"
require "support/vcr_setup"

# This test validates the Prompt class functionality with VCR recorded API calls for Claude 3.7 Sonnet thinking model
# VCR records API responses in test/vcr_cassettes/ directory
# When a test runs:
# - If a cassette exists, it will replay the recorded responses
# - If no cassette exists, it will make real API calls and record them
class ClaudeSonnetThinkingPromptTest < ActiveSupport::TestCase

  class TestPrompt < Prompt

    def initialize(model: "anthropic/claude-3.7-sonnet:thinking", system: "You are a helpful assistant.", user: "Hello, world!")
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

  test "executes to string with Claude 3.7 Sonnet thinking model" do
    VCR.use_cassette("prompt/execute_to_string_claude_sonnet_thinking") do
      # Create a test prompt
      test_prompt = TestPrompt.new(
        model: "anthropic/claude-3.7-sonnet:thinking",
        system: "You are a helpful assistant.",
        user: "What is the capital of Spain?"
      )

      # Test non-streaming response
      response = test_prompt.execute_to_string
      assert response.present?

      # The Prompt class should abstract away the differences in response formats
      # Just check the response for the expected content
      text = response.to_s
      assert_includes text.downcase, "madrid", "Expected response to contain 'madrid'"
    end
  end

  test "executes to json with Claude 3.7 Sonnet thinking model" do
    VCR.use_cassette("prompt/execute_to_json_claude_sonnet_thinking") do
      # Create a test prompt that asks for a JSON response with multiple objects
      test_prompt = TestPrompt.new(
        model: "anthropic/claude-3.7-sonnet:thinking",
        system: "You are a helpful assistant. Always respond with valid JSON objects. Generate SEPARATE COMPLETE JSON OBJECTS without any explanations or text between them.",
        user: "List 3 South American countries and their capitals in JSON format. Each country should be a separate JSON object with 'country' and 'capital' fields."
      )

      # Track how many objects we receive
      json_objects_received = []

      # Test streaming JSON response
      response = test_prompt.execute_to_json do |json_object|
        json_objects_received << json_object
      end

      # Verify the response overall
      assert response.present?
      assert_kind_of Hash, response

      # Verify the block was called with multiple objects
      assert_equal 3, json_objects_received.length,
        "Expected to receive 3 JSON objects during streaming, but got #{json_objects_received.length}"

      # Verify each JSON object has the expected structure
      json_objects_received.each do |obj|
        assert obj.key?("country"), "Expected JSON object to have 'country' key"
        assert obj.key?("capital"), "Expected JSON object to have 'capital' key"
      end

      # Verify we got 3 different countries
      countries = json_objects_received.map { |obj| obj["country"] }
      assert_equal 3, countries.uniq.length, "Expected 3 different countries"
    end
  end

  test "executes with output to PromptOutput object using Claude 3.7 Sonnet thinking model" do
    VCR.use_cassette("prompt/execute_to_prompt_output_claude_sonnet_thinking") do
      # Create a test prompt
      test_prompt = TestPrompt.new(
        model: "anthropic/claude-3.7-sonnet:thinking",
        system: "You are a helpful assistant.",
        user: "What is the capital of Brazil?"
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
      assert_includes prompt_output.output.downcase, "brasília", "Expected response to contain 'brasília'"

      # Verify response is the raw API response
      assert_kind_of Hash, response
      assert response.present?, "Expected Claude thinking response to be present"
    end
  end

end
