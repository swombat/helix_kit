require "test_helper"
require "support/vcr_setup"

# This test validates the Prompt class functionality with VCR recorded API calls for GPT-4o model
# VCR records API responses in test/vcr_cassettes/ directory
# When a test runs:
# - If a cassette exists, it will replay the recorded responses
# - If no cassette exists, it will make real API calls and record them
class GPT4oPromptTest < ActiveSupport::TestCase

  class TestPrompt < Prompt

    def initialize(model: "openai/chatgpt-4o-latest", system: "You are a helpful assistant.", user: "Hello, world!")
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

  test "executes to string with 4o model" do
    VCR.use_cassette("prompt/execute_to_string_4o") do
      # Create a test prompt
      test_prompt = TestPrompt.new(
        model: "openai/chatgpt-4o-latest",
        system: "You are a helpful assistant.",
        user: "What is the capital of France?"
      )

      # Test non-streaming response
      response = test_prompt.execute_to_string
      assert response.present?

      # Check for Paris in the response
      # Response might be a string or a hash with a content
      text = response.is_a?(Hash) ?
        (response["choices"]&.first&.dig("message", "content") || response.to_s) :
        response.to_s

      assert_includes text.downcase, "paris", "Expected response to contain 'paris'"
    end
  end

  test "executes to json with 4o model" do
    VCR.use_cassette("prompt/execute_to_json_4o") do
      # Create a test prompt that asks for a JSON response with multiple objects
      test_prompt = TestPrompt.new(
        model: "openai/chatgpt-4o-latest",
        system: "You are a helpful assistant. Always respond with valid JSON objects.",
        user: "List 3 European countries and their capitals in JSON format. Each country should be a separate JSON object with 'country' and 'capital' fields."
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
      assert json_objects_received.length == 3, "Expected to receive 3 JSON objects"

      # Verify each JSON object has the expected structure
      json_objects_received.each do |obj|
        assert obj.key?("country") || obj.key?("capital") || obj.has_key?(obj.keys.first),
          "Expected JSON object to have country/capital keys or contain nested objects"
      end
    end
  end

  test "executes with output to PromptOutput object" do
    VCR.use_cassette("prompt/execute_to_prompt_output_4o") do
      # Create a test prompt
      test_prompt = TestPrompt.new(
        model: "openai/chatgpt-4o-latest",
        system: "You are a helpful assistant.",
        user: "What is the capital of Germany?"
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
      assert_includes prompt_output.output.downcase, "berlin", "Expected response to contain 'berlin'"

      # Verify response is the raw API response
      assert_kind_of Hash, response
      assert response.key?("choices"), "Expected response to include 'choices' key"
    end
  end

  test "executes with output_json when json parameter is true using 4o model" do
    VCR.use_cassette("prompt/execute_to_prompt_output_json_4o") do
      # Create a test prompt requesting JSON response
      test_prompt = TestPrompt.new(
        model: "openai/chatgpt-4o-latest",
        system: "You are a helpful assistant. Always respond with valid JSON.",
        user: "List 3 Australian cities in JSON format. Include name, state, and population for each."
      )

      # Create a PromptOutput record
      prompt_output = PromptOutput.create(account: @account, output_json: [])
      assert prompt_output.persisted?

      # Execute with output to PromptOutput and json parameter set to true
      response = test_prompt.execute(
        output_class: "PromptOutput",
        output_id: prompt_output.id,
        output_property: :output_json,
        json: true
      )

      # Refresh from database
      prompt_output.reload

      # Verify output field should NOT be populated (using output_json instead)
      assert_nil prompt_output.output, "Expected PromptOutput's output field to be nil when json is true"

      # Verify JSON content was saved to the output_json field
      assert prompt_output.output_json.present?, "Expected PromptOutput's output_json field to be populated"

      # Parse the JSON to verify structure
      parsed_json = prompt_output.output_json
      assert parsed_json.is_a?(Array), "Expected JSON to be an array"
      assert_equal 3, parsed_json.length, "Expected 3 cities in the JSON response"

      # Check structure of the first city
      first_city = parsed_json.first
      assert first_city.key?("name"), "Expected each city to have a name"
      assert first_city.key?("state"), "Expected each city to have a state"
      assert first_city.key?("population"), "Expected each city to have a population"

      # Verify response is the raw API response
      assert_kind_of Hash, response
      assert response.present?, "Expected 4o response to be present"
    end
  end

end
