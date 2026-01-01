require "test_helper"

class OpenRouterClaudeOpus45ThinkingTest < ActiveSupport::TestCase

  test "gets response from anthropic/claude-opus-4.5 model" do
    VCR.use_cassette("openrouter_opus45_basic_response") do
      response = OpenRouterApi.new.get_response(
        params: {
          model: "anthropic/claude-opus-4.5",
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

  test "streams text response from anthropic/claude-opus-4.5 model and captures reasoning chunks" do
    VCR.use_cassette("openrouter_opus45_stream_reasoning_response") do
      received_chunks = []
      reasoning_chunks = []
      full_response = ""

      # Use raw streaming to capture reasoning field
      client = OpenAI::Client.new(
        uri_base: "https://openrouter.ai/api/v1",
        access_token: Rails.application.credentials.dig(:ai, :openrouter, :api_token),
        request_timeout: 60
      )

      parameters = {
        model: "anthropic/claude-opus-4.5",
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

      # Log what we found for analysis
      puts "\n=== Claude Opus 4.5 Streaming Analysis ==="
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

  test "checks if anthropic/claude-opus-4.5 supports thinking mode suffix" do
    VCR.use_cassette("openrouter_opus45_thinking_mode_response") do
      # Try the :thinking suffix like claude-3.7-sonnet:thinking
      client = OpenAI::Client.new(
        uri_base: "https://openrouter.ai/api/v1",
        access_token: Rails.application.credentials.dig(:ai, :openrouter, :api_token),
        request_timeout: 60
      )

      reasoning_chunks = []
      full_response = ""

      begin
        parameters = {
          model: "anthropic/claude-opus-4.5:thinking",
          messages: [
            { role: "system", content: "Think carefully about the problem." },
            { role: "user", content: "What is 27 * 13?" }
          ],
          stream: proc do |chunk, _bytesize|
            delta = chunk.dig("choices", 0, "delta")
            next unless delta

            reasoning = delta["reasoning"]
            content = delta["content"]

            reasoning_chunks << reasoning if reasoning.present?
            full_response += content if content.present?
          end
        }

        client.chat(parameters: parameters)

        puts "\n=== Claude Opus 4.5:thinking Mode Test ==="
        puts "Reasoning chunks found: #{reasoning_chunks.size}"
        puts "Has streaming reasoning: #{reasoning_chunks.any?(&:present?)}"
        if reasoning_chunks.any?(&:present?)
          puts "Sample reasoning: #{reasoning_chunks.first(5).join}"
        end
        puts "=== End Analysis ===\n"

      rescue => e
        puts "\n=== Claude Opus 4.5:thinking Mode Error ==="
        puts "Error: #{e.message}"
        puts "The :thinking suffix may not be supported for this model"
        puts "=== End Analysis ===\n"
      end
    end
  end

end
