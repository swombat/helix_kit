require "test_helper"

class OpenRouterGrok4ThinkingTest < ActiveSupport::TestCase

  test "gets response from x-ai/grok-4 model" do
    VCR.use_cassette("openrouter_grok4_basic_response") do
      response = OpenRouterApi.new.get_response(
        params: {
          model: "x-ai/grok-4",
          system: "Be helpful",
          user: "Hi, please help."
        }
      )

      assert_not_nil response
      assert_includes response.keys, "id"
      assert_includes response.keys, "choices"

      text_content = response["choices"][0]["message"]["content"]
      assert text_content.present?
    end
  end

  test "streams text response from x-ai/grok-4 model and captures reasoning chunks" do
    VCR.use_cassette("openrouter_grok4_stream_reasoning_response") do
      received_chunks = []
      reasoning_chunks = []
      full_response = ""

      client = OpenAI::Client.new(
        uri_base: "https://openrouter.ai/api/v1",
        access_token: Rails.application.credentials.dig(:ai, :openrouter, :api_token),
        request_timeout: 120  # Grok 4 can be slow
      )

      parameters = {
        model: "x-ai/grok-4",
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

      assert_operator received_chunks.size, :>, 0, "Expected to receive stream chunks"
      assert full_response.present?, "Expected non-empty response"

      has_reasoning = reasoning_chunks.any?(&:present?)

      puts "\n=== Grok 4 Streaming Analysis ==="
      puts "Total chunks received: #{received_chunks.size}"
      puts "Reasoning chunks found: #{reasoning_chunks.size}"
      puts "Has streaming reasoning: #{has_reasoning}"
      if has_reasoning
        puts "Sample reasoning: #{reasoning_chunks.first(3).join}"
      end
      puts "Note: Grok 4 docs say 'reasoning is not exposed'"
      puts "=== End Analysis ===\n"
    end
  end

  test "gets response from x-ai/grok-4-fast model" do
    VCR.use_cassette("openrouter_grok4fast_basic_response") do
      response = OpenRouterApi.new.get_response(
        params: {
          model: "x-ai/grok-4-fast",
          system: "Be helpful",
          user: "Hi, please help."
        }
      )

      assert_not_nil response
      assert_includes response.keys, "id"
      assert_includes response.keys, "choices"

      text_content = response["choices"][0]["message"]["content"]
      assert text_content.present?
    end
  end

  test "streams x-ai/grok-4-fast with reasoning enabled via parameter" do
    VCR.use_cassette("openrouter_grok4fast_reasoning_enabled_response") do
      received_chunks = []
      reasoning_chunks = []
      full_response = ""

      client = OpenAI::Client.new(
        uri_base: "https://openrouter.ai/api/v1",
        access_token: Rails.application.credentials.dig(:ai, :openrouter, :api_token),
        request_timeout: 120
      )

      # Per OpenRouter docs: "Reasoning can be enabled using the `reasoning` `enabled` parameter"
      parameters = {
        model: "x-ai/grok-4-fast",
        messages: [
          { role: "system", content: "Think step by step about the problem before answering." },
          { role: "user", content: "What is 27 * 13? Show your work." }
        ],
        temperature: 0.7,
        reasoning: { enabled: true },  # Enable reasoning explicitly
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

      assert_operator received_chunks.size, :>, 0, "Expected to receive stream chunks"

      has_reasoning = reasoning_chunks.any?(&:present?)

      puts "\n=== Grok 4 Fast (reasoning: enabled) Streaming Analysis ==="
      puts "Total chunks received: #{received_chunks.size}"
      puts "Reasoning chunks found: #{reasoning_chunks.size}"
      puts "Has streaming reasoning: #{has_reasoning}"
      if has_reasoning
        puts "Sample reasoning: #{reasoning_chunks.first(5).join}"
      end
      puts "=== End Analysis ===\n"
    end
  end

  test "streams x-ai/grok-4-fast without reasoning enabled (baseline)" do
    VCR.use_cassette("openrouter_grok4fast_no_reasoning_response") do
      received_chunks = []
      reasoning_chunks = []
      full_response = ""

      client = OpenAI::Client.new(
        uri_base: "https://openrouter.ai/api/v1",
        access_token: Rails.application.credentials.dig(:ai, :openrouter, :api_token),
        request_timeout: 60
      )

      parameters = {
        model: "x-ai/grok-4-fast",
        messages: [
          { role: "system", content: "Be helpful." },
          { role: "user", content: "What is 27 * 13?" }
        ],
        temperature: 0.7,
        # No reasoning parameter - should be faster, no reasoning output
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

      has_reasoning = reasoning_chunks.any?(&:present?)

      puts "\n=== Grok 4 Fast (no reasoning param) Streaming Analysis ==="
      puts "Total chunks received: #{received_chunks.size}"
      puts "Reasoning chunks found: #{reasoning_chunks.size}"
      puts "Has streaming reasoning: #{has_reasoning}"
      puts "=== End Analysis ===\n"
    end
  end

end
