require "test_helper"
require "ostruct"

class Message::RecordProviderResponseTest < ActiveSupport::TestCase

  setup do
    @user = User.create!(email_address: "rpr-#{SecureRandom.hex(4)}@example.com", password: "password123")
    @user.profile.update!(first_name: "Test", last_name: "User")
    @account = @user.personal_account
    @chat = @account.chats.create!(model_id: "openrouter/auto")
    @ai_message = @chat.messages.create!(role: "assistant", content: "")
  end

  test "Anthropic raw with thinking signature populates replay_payload" do
    rlm = build_rlm(
      provider: "anthropic",
      content: "Direct API thinking response.",
      thinking: RubyLLM::Thinking.new(text: "Reasoning text", signature: "anthropic-sig-abc"),
      model_id: "claude-opus-4-5-20251101",
      input_tokens: 200, output_tokens: 80, thinking_tokens: 32,
      raw: { "usage" => { "cache_read_input_tokens" => 50, "cache_creation_input_tokens" => 10 } }
    )

    @ai_message.record_provider_response!(rlm, provider: rlm.provider.to_sym, tool_names: [])
    @ai_message.reload

    assert_equal "Direct API thinking response.", @ai_message.content
    assert_equal "Reasoning text", @ai_message.thinking_text
    assert_equal "anthropic-sig-abc", @ai_message.thinking_signature
    assert_equal "anthropic", @ai_message.replay_payload["provider"]
    assert_equal "Reasoning text", @ai_message.replay_payload.dig("thinking", "text")
    assert_equal 50, @ai_message.cached_tokens
    assert_equal 10, @ai_message.cache_creation_tokens
    assert_equal 32, @ai_message.thinking_tokens
    assert_equal "claude-opus-4-5-20251101", @ai_message.model_id_string
  end

  test "OpenRouter raw with reasoning_details populates replay_payload" do
    details = [ { "type" => "reasoning.text", "text" => "thinking step 1" } ]
    rlm = build_rlm(
      provider: "openrouter",
      content: "OpenRouter response.",
      thinking: nil,
      model_id: "openai/gpt-5.2",
      input_tokens: 150, output_tokens: 60,
      raw: {
        "choices" => [ { "message" => { "reasoning_details" => details } } ],
        "usage" => { "prompt_tokens_details" => { "cached_tokens" => 25 } }
      }
    )

    @ai_message.record_provider_response!(rlm, provider: rlm.provider.to_sym, tool_names: [])
    @ai_message.reload

    assert_equal "openrouter", @ai_message.replay_payload["provider"]
    assert_equal details, @ai_message.replay_payload["reasoning_details"]
    assert_equal 25, @ai_message.cached_tokens
  end

  test "Gemini raw with tool call thoughtSignature populates tool_calls.replay_payload" do
    tool_call = OpenStruct.new(id: "call_1", name: "WebTool", arguments: { url: "https://example.com" }, thought_signature: "gemini-tool-sig-9")
    rlm = build_rlm(
      provider: "gemini",
      content: "Used a tool.",
      thinking: nil,
      model_id: "gemini-3-pro-preview",
      input_tokens: 100, output_tokens: 40,
      tool_calls: [ tool_call ],
      raw: {}
    )

    @ai_message.record_provider_response!(rlm, provider: rlm.provider.to_sym, tool_names: [ "WebTool" ])
    @ai_message.reload

    tc = @ai_message.tool_calls.find_by!(tool_call_id: "call_1")
    assert_equal "gemini", tc.replay_payload["provider"]
    assert_equal "gemini-tool-sig-9", tc.replay_payload["thought_signature"]
    assert_equal "gemini-tool-sig-9", tc.thought_signature
  end

  test "Gemini top-level thought_signature populates message replay_payload" do
    rlm = build_rlm(
      provider: "gemini",
      content: "Gemini response.",
      thinking: nil,
      model_id: "gemini-3-pro-preview",
      input_tokens: 80, output_tokens: 30,
      thought_signature: "gemini-msg-sig-7",
      raw: {}
    )

    @ai_message.record_provider_response!(rlm, provider: rlm.provider.to_sym)
    @ai_message.reload

    assert_equal "gemini", @ai_message.replay_payload["provider"]
    assert_equal "gemini-msg-sig-7", @ai_message.replay_payload["thought_signature"]
  end

  test "tools_used preserves existing value when no new tool names supplied" do
    @ai_message.update!(tools_used: [ "PriorTool" ])
    rlm = build_rlm(provider: "openrouter", content: "Reply", model_id: "openai/gpt-5", input_tokens: 1, output_tokens: 1, raw: {})

    @ai_message.record_provider_response!(rlm, provider: rlm.provider.to_sym, tool_names: [])
    assert_equal [ "PriorTool" ], @ai_message.reload.tools_used
  end

  test "anthropic_replay_payload returns nil when no signature" do
    rlm = build_rlm(provider: "anthropic", content: "No-thinking reply", thinking: RubyLLM::Thinking.new(text: nil, signature: nil), model_id: "claude-haiku-4-5-20251001", input_tokens: 1, output_tokens: 1, raw: {})

    @ai_message.record_provider_response!(rlm, provider: rlm.provider.to_sym)
    assert_nil @ai_message.reload.replay_payload
  end

  private

  def build_rlm(provider:, content:, model_id:, input_tokens:, output_tokens:, raw:, thinking: nil, thinking_tokens: nil, tool_calls: [], thought_signature: nil)
    OpenStruct.new(
      provider:           provider,
      content:            content,
      thinking:           thinking,
      thinking_tokens:    thinking_tokens,
      input_tokens:       input_tokens,
      output_tokens:      output_tokens,
      model_id:           model_id,
      tool_calls:         tool_calls,
      thought_signature:  thought_signature,
      raw:                raw
    )
  end

end
