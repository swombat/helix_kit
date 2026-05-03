require "test_helper"
require "net/http"
require "json"

class AnthropicDirectThinkingTest < ActiveSupport::TestCase

  def api_key
    Rails.application.credentials.dig(:ai, :claude, :api_token)
  end

  def make_anthropic_request(model:, messages:, system: nil, thinking: nil, stream: false)
    uri = URI("https://api.anthropic.com/v1/messages")

    payload = {
      model: model,
      max_tokens: thinking ? 16000 : 4096,  # Must be > budget_tokens when thinking enabled
      messages: messages
    }

    payload[:system] = system if system
    payload[:thinking] = thinking if thinking
    payload[:stream] = stream

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.read_timeout = 120

    request = Net::HTTP::Post.new(uri)
    request["Content-Type"] = "application/json"
    request["x-api-key"] = api_key
    request["anthropic-version"] = "2023-06-01"
    request.body = payload.to_json

    if stream
      chunks = []
      http.request(request) do |response|
        response.read_body do |chunk|
          chunks << chunk
        end
      end
      chunks.join
    else
      response = http.request(request)
      JSON.parse(response.body)
    end
  end

  test "Claude 3.7 Sonnet with extended thinking via Anthropic API" do
    VCR.use_cassette("anthropic_direct_sonnet37_thinking") do
      response = make_anthropic_request(
        model: "claude-3-7-sonnet-20250219",
        system: "You are a helpful assistant.",
        messages: [
          { role: "user", content: "What is 27 * 13? Think through it step by step." }
        ],
        thinking: {
          type: "enabled",
          budget_tokens: 5000
        }
      )

      assert_thinking_response(response)
    end
  end

  test "Claude Sonnet 4 with extended thinking via Anthropic API" do
    VCR.use_cassette("anthropic_direct_sonnet4_thinking") do
      response = make_anthropic_request(
        model: "claude-sonnet-4-20250514",
        system: "You are a helpful assistant.",
        messages: [
          { role: "user", content: "What is 27 * 13? Think through it step by step." }
        ],
        thinking: {
          type: "enabled",
          budget_tokens: 5000
        }
      )

      assert_thinking_response(response)
    end
  end

  test "Claude Opus 4 with extended thinking via Anthropic API" do
    VCR.use_cassette("anthropic_direct_opus4_thinking") do
      response = make_anthropic_request(
        model: "claude-opus-4-20250514",
        system: "You are a helpful assistant.",
        messages: [
          { role: "user", content: "What is 27 * 13? Think through it step by step." }
        ],
        thinking: {
          type: "enabled",
          budget_tokens: 5000
        }
      )

      assert_thinking_response(response)
    end
  end

  test "Claude Opus 4.1 with extended thinking via Anthropic API" do
    VCR.use_cassette("anthropic_direct_opus41_thinking") do
      response = make_anthropic_request(
        model: "claude-opus-4-1-20250805",
        system: "You are a helpful assistant.",
        messages: [
          { role: "user", content: "What is 27 * 13? Think through it step by step." }
        ],
        thinking: {
          type: "enabled",
          budget_tokens: 5000
        }
      )

      assert_thinking_response(response)
    end
  end

  test "Claude 3.7 Sonnet streaming with extended thinking via Anthropic API" do
    VCR.use_cassette("anthropic_direct_sonnet37_thinking_stream") do
      raw_response = make_anthropic_request(
        model: "claude-3-7-sonnet-20250219",
        system: "You are a helpful assistant.",
        messages: [
          { role: "user", content: "What is 27 * 13?" }
        ],
        thinking: {
          type: "enabled",
          budget_tokens: 5000
        },
        stream: true
      )

      thinking_chunks = []
      text_chunks = []

      raw_response.split("\n").each do |line|
        next unless line.start_with?("data: ")
        data = line.sub("data: ", "").strip
        next if data == "[DONE]" || data.empty?

        begin
          event = JSON.parse(data)
          event_type = event["type"]

          case event_type
          when "content_block_delta"
            delta = event.dig("delta")
            if delta
              if delta["type"] == "thinking_delta"
                thinking_chunks << delta["thinking"]
              elsif delta["type"] == "text_delta"
                text_chunks << delta["text"]
              end
            end
          end
        rescue JSON::ParserError
          # Skip malformed JSON
        end
      end

      assert thinking_chunks.any?, "Expected to receive thinking chunks in streaming"
      assert text_chunks.any?, "Expected to receive text chunks in streaming"
    end
  end

  private

  def assert_thinking_response(response)
    assert_not_nil response
    refute response["error"], "Should not have an error: #{response['error']}"

    content_blocks = response["content"] || []
    assert content_blocks.any? { |block| block["type"] == "thinking" }, "Expected a thinking block"
    assert content_blocks.any? { |block| block["type"] == "text" }, "Expected a text block"
    assert response["usage"].present?, "Expected usage metadata"
  end

end
