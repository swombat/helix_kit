require "test_helper"

class OpenRouterGemini3ProThinkingTest < ActiveSupport::TestCase

  test "gets response from google/gemini-3-pro-preview model" do
    VCR.use_cassette("openrouter_gemini3pro_basic_response") do
      response = OpenRouterApi.new.get_response(
        params: {
          model: "google/gemini-3-pro-preview",
          system: "Be helpful",
          user: "Hi, please help."
        }
      )

      assert_not_nil response
      assert_includes response.keys, "id"
      assert_includes response.keys, "choices"

      # Check the actual content of the response
      text_content = response["choices"][0]["message"]["content"]
      assert text_content.present?
    end
  end

  test "streams text response from google/gemini-3-pro-preview model and captures reasoning chunks" do
    VCR.use_cassette("openrouter_gemini3pro_stream_reasoning_response") do
      received_chunks = []
      reasoning_chunks = []
      full_response = ""

      client = OpenAI::Client.new(
        uri_base: "https://openrouter.ai/api/v1",
        access_token: Rails.application.credentials.dig(:ai, :openrouter, :api_token),
        request_timeout: 60
      )

      parameters = {
        model: "google/gemini-3-pro-preview",
        messages: [
          { role: "system", content: "Think step by step about the problem before answering." },
          { role: "user", content: "What is 27 * 13? Show your work." }
        ],
        temperature: 0.7,
        stream: proc do |chunk, _bytesize|
          delta = chunk.dig("choices", 0, "delta")
          next unless delta

          content = delta["content"]
          reasoning = delta["reasoning"]

          received_chunks << { content: content, reasoning: reasoning }
          reasoning_chunks << reasoning if reasoning.present?
          full_response += content if content.present?
        end
      }

      client.chat(parameters: parameters)

      # Verify streaming worked
      assert_operator received_chunks.size, :>, 0, "Expected to receive stream chunks"
      assert full_response.present?, "Expected non-empty response"

      # Check if any reasoning was streamed
      has_reasoning = reasoning_chunks.any?(&:present?)

      puts "\n=== Gemini 3 Pro Streaming Analysis ==="
      puts "Total chunks received: #{received_chunks.size}"
      puts "Reasoning chunks found: #{reasoning_chunks.size}"
      puts "Has streaming reasoning: #{has_reasoning}"
      if has_reasoning
        puts "Sample reasoning: #{reasoning_chunks.first(3).join}"
      end
      puts "Final response length: #{full_response.length}"
      puts "=== End Analysis ===\n"
    end
  end

  test "checks google/gemini-3-pro-preview non-streaming response for reasoning field" do
    VCR.use_cassette("openrouter_gemini3pro_reasoning_field_response") do
      client = OpenAI::Client.new(
        uri_base: "https://openrouter.ai/api/v1",
        access_token: Rails.application.credentials.dig(:ai, :openrouter, :api_token),
        request_timeout: 60
      )

      response = client.chat(
        parameters: {
          model: "google/gemini-3-pro-preview",
          messages: [
            { role: "system", content: "Think step by step." },
            { role: "user", content: "What is 27 * 13?" }
          ],
          temperature: 0.7
        }
      )

      message = response.dig("choices", 0, "message")
      content = message["content"]
      reasoning = message["reasoning"]

      puts "\n=== Gemini 3 Pro Non-Streaming Analysis ==="
      puts "Content present: #{content.present?}"
      puts "Reasoning field present: #{reasoning.present?}"
      if reasoning.present?
        puts "Reasoning sample: #{reasoning[0..200]}..."
      end
      puts "=== End Analysis ===\n"
    end
  end

end
