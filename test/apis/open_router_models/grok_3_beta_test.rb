require "test_helper"

class OpenRouterGrok3BetaTest < ActiveSupport::TestCase

  test "gets response from x-ai/grok-3-beta model" do
    VCR.use_cassette("openrouter_grok3beta_basic_response") do
      response = OpenRouterApi.new.get_response(
        params: {
          model: "x-ai/grok-3-beta",
          system: "Be helpful",
          user: "Hi, please help.",
          stream: false
        }
      )

      assert_not_nil response
      assert_includes response.keys, "id"
      assert_includes response.keys, "choices"
      assert_includes response.keys, "usage"

      # The model identifier might be returned differently by OpenRouter
      # Check for either the full identifier or a shortened version
      model_identifier = response["model"]
      assert model_identifier.include?("grok") || model_identifier.include?("Grok"),
            "Expected model identifier to include 'grok' or 'Grok'"

      # Check the actual content of the response
      text_content = response["choices"][0]["message"]["content"]
      assert text_content.present?
    end
  end

  test "streams text response from x-ai/grok-3-beta model" do
    VCR.use_cassette("openrouter_grok3beta_stream_text_response") do
      # Variables to track streaming
      received_chunks = []
      full_response = ""

      # Define the streaming callback
      stream_proc = lambda do |resp, delta|
        received_chunks << delta
        full_response = resp
      end

      response = OpenRouterApi.new.get_response(
        params: {
          model: "x-ai/grok-3-beta",
          system: "Be helpful",
          user: "Write a short poem about coding."
        },
        stream_proc: stream_proc
      )

      # Verify streaming worked - we should have received chunks
      assert_operator received_chunks.size, :>, 0, "Expected to receive stream chunks"

      # Verify we got a complete response text
      assert full_response.present?

      # Verify standard response structure
      assert_includes response.keys, "id"
      assert_includes response.keys, "choices"
      assert_includes response.keys, "usage"

      # Get the final text from the response and verify it's present
      text_content = response["choices"][0]["message"]["content"]
      assert text_content.present?
      assert_equal full_response, text_content

      # Verify that streaming chunks were accumulated correctly
      assert_equal text_content, full_response, "The streamed content should match the final response"
    end
  end

  test "gets json response from x-ai/grok-3-beta model" do
    VCR.use_cassette("openrouter_grok3beta_json_response") do
      response = OpenRouterApi.new.get_response(
        params: {
          model: "x-ai/grok-3-beta",
          system: "You are a JSON generator. ONLY respond with valid JSON. No markdown, no backticks, no explanations before or after the JSON.",
          user: "Generate a JSON object with information about Ruby. Include keys: name, description, creator, year_created, and key_features (array of 3 features)."
        }
      )

      # Test response structure
      assert_not_nil response
      assert_includes response.keys, "id"
      assert_includes response.keys, "choices"
      assert_includes response.keys, "usage"

      # Check the model name
      assert response["model"].include?("grok") || response["model"].include?("Grok"),
            "Expected model to include 'grok' or 'Grok'"

      # Verify we received content in the response
      text_content = response["choices"][0]["message"]["content"]
      assert text_content.present?

      # Handle possible markdown formatting in response
      if text_content.include?("```json") || text_content.include?("```")
        # Extract JSON content from code blocks
        json_string = text_content.match(/```(?:json)?\s*(.*?)```/m)&.[](1)
        # If we found a match, use it, otherwise use the raw content
        json_string = json_string.presence || text_content
      else
        json_string = text_content
      end

      # Parse the JSON
      json_data = JSON.parse(json_string)

      # Check required fields
      assert_includes json_data.keys, "name"
      assert_includes json_data.keys, "description"
      assert_includes json_data.keys, "creator"
      assert_includes json_data.keys, "year_created"
      assert_includes json_data.keys, "key_features"

      # Check array field
      assert json_data["key_features"].is_a?(Array)
      assert_equal 3, json_data["key_features"].size

      # Check specific Ruby-related content
      assert_equal "Ruby", json_data["name"]
      # The creator might be formatted differently by different models
      assert json_data["creator"].is_a?(String) && json_data["creator"].present?,
            "Expected creator to be a non-empty string"

      # Check that all features are present and non-empty
      json_data["key_features"].each do |feature|
        assert feature.present?, "Feature should not be empty"
      end
    end
  end

  test "streams json response from x-ai/grok-3-beta model" do
    VCR.use_cassette("openrouter_grok3beta_stream_json_response") do
      # Variables to track streaming
      received_json_objects = []

      # Define the streaming callback for JSON
      stream_proc = lambda do |json_obj|
        received_json_objects << json_obj if json_obj.present?
      end

      response = OpenRouterApi.new.get_response(
        params: {
          model: "x-ai/grok-3-beta",
          system: "You are a JSON generator. ONLY respond with valid JSON. No markdown, no backticks, no explanations. Generate 3 separate complete JSON objects that I can parse individually.",
          user: "Generate 3 JSON objects with information about programming languages. Each object should include name, type, and popular_use_case."
        },
        stream_proc: stream_proc,
        stream_response_type: :json
      )

      # Verify streaming worked
      assert_operator received_json_objects.size, :>, 0, "Expected to receive JSON objects during streaming"

      # Check response structure
      assert_includes response.keys, "id"
      assert_includes response.keys, "choices"
      assert_includes response.keys, "usage"

      # Check that at least one JSON object was received during streaming
      assert received_json_objects.any? { |obj| obj.is_a?(Hash) },
            "Expected to receive at least one valid JSON object during streaming"

      # Check that each received object has the expected structure
      received_json_objects.each do |obj|
        if obj.is_a?(Hash) && obj["name"].present?
          assert_includes obj.keys, "name", "JSON object should have a 'name' key"
          assert obj["name"].is_a?(String), "'name' should be a string"
        end
      end

      # Get the final JSON content and verify its structure
      final_content = response["choices"][0]["message"]["content"]
      assert final_content.present?

      # The final content may contain multiple JSON objects, so we'll check if
      # it contains at least one valid JSON object
      assert final_content.include?("{") && final_content.include?("}"),
            "Final content should contain at least one JSON object"
    end
  end

end
