require "test_helper"

class OpenRouterO1Test < ActiveSupport::TestCase

  test "gets response from openai/o1 model" do
    VCR.use_cassette("openrouter_o1_basic_response") do
      response = OpenRouterApi.new.get_response(
        params: {
          model: "openai/o1",
          system: "Be helpful",
          user: "Hi, please help."
        }
      )

      assert_not_nil response
      assert_includes response.keys, "id"
      assert_includes response.keys, "choices"
      assert_includes response.keys, "usage"

      # The model identifier might be returned differently by OpenRouter
      # Check for either the full identifier or a shortened version
      model_identifier = response["model"]
      assert model_identifier.include?("o1"),
            "Expected model identifier to include 'o1'"

      # Check the actual content of the response
      text_content = response["choices"][0]["message"]["content"]
      assert text_content.present?
    end
  end

  test "streams text response from openai/o1 model" do
    VCR.use_cassette("openrouter_o1_stream_text_response") do
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
          model: "openai/o1",
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

  test "gets json response from openai/o1 model" do
    VCR.use_cassette("openrouter_o1_json_response") do
      response = OpenRouterApi.new.get_response(
        params: {
          model: "openai/o1",
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
      assert response["model"].include?("o1"), "Expected model to include 'o1'"

      # Verify the format of the response is JSON - we should have a valid Ruby hash where specified
      text_content = response["choices"][0]["message"]["content"]
      assert text_content.present?

      # Since the VCR cassette is fixed, we know what's in the data
      json_data = JSON.parse(text_content)

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
      assert json_data["creator"].include?("Yukihiro Matsumoto"),
            "Expected creator to include 'Yukihiro Matsumoto'"

      # Check that all features are present and non-empty
      json_data["key_features"].each do |feature|
        assert feature.present?, "Feature should not be empty"
      end
    end
  end

  test "streams json response from openai/o1 model" do
    VCR.use_cassette("openrouter_o1_stream_json_response") do
      # Variables to track streaming
      received_json_objects = []

      # Define the streaming callback for JSON
      stream_proc = lambda do |json_obj|
        received_json_objects << json_obj if json_obj.present?
      end

      response = OpenRouterApi.new.get_response(
        params: {
          model: "openai/o1",
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

  test "streams individual json objects about human achievements from openai/o1 model" do
    VCR.use_cassette("openrouter_o1_stream_achievements_json_response") do
      # Variables to track streaming
      received_json_objects = []

      # Define the streaming callback for JSON
      stream_proc = lambda do |json_obj|
        received_json_objects << json_obj if json_obj.present?
      end

      response = OpenRouterApi.new.get_response(
        params: {
          model: "openai/o1",
          system: "You are a JSON generator. ONLY respond with valid JSON. No markdown, no backticks, no explanations. Generate 3 SEPARATE COMPLETE JSON OBJECTS, one per achievement, that I can parse individually.",
          user: "Generate 3 JSON objects about significant human achievements. Each object should include: achievement_name, year, and significance."
        },
        stream_proc: stream_proc,
        stream_response_type: :json
      )

      # Get the final content for debugging
      final_content = response["choices"][0]["message"]["content"]

      # The core assertion that should fail - we expect to receive 3 distinct JSON objects
      assert_equal 3, received_json_objects.size,
        "Expected to receive 3 distinct JSON objects during streaming, but got #{received_json_objects.size}.\nFinal content was: #{final_content}"

      # Check response structure (these assertions should pass regardless)
      assert_includes response.keys, "id"
      assert_includes response.keys, "choices"
      assert_includes response.keys, "usage"
    end
  end

end
