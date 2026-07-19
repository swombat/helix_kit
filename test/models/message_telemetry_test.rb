require "test_helper"

class MessageTelemetryTest < ActiveSupport::TestCase

  setup do
    @user = users(:user_1)
    @chat = accounts(:personal_account).chats.create!(model_id: "openrouter/auto")
  end

  test "reports RubyLLM token categories without treating zero as missing" do
    message = @chat.messages.create!(
      role: "assistant",
      content: "Measured response",
      model_id_string: "google/gemini-2.5-pro",
      input_tokens: 1_000,
      output_tokens: 0,
      cached_tokens: 800,
      cache_creation_tokens: 100
    )

    assert_equal(
      {
        model: "google/gemini-2.5-pro",
        instrumentation_complete: true,
        input_tokens: 1_000,
        output_tokens: 0,
        cache_read_tokens: 800,
        cache_write_tokens: 100
      },
      message.ruby_llm_telemetry
    )
  end

  test "marks telemetry incomplete when a provider category is unavailable" do
    message = @chat.messages.create!(
      role: "assistant",
      content: "Partially measured response",
      input_tokens: 100,
      output_tokens: 20
    )

    assert_not message.ruby_llm_telemetry[:instrumentation_complete]
    assert_nil message.ruby_llm_telemetry[:cache_read_tokens]
    assert_nil message.ruby_llm_telemetry[:cache_write_tokens]
  end

  test "only adds telemetry to JSON when explicitly requested" do
    message = @chat.messages.create!(
      role: "assistant",
      content: "Measured response",
      input_tokens: 100,
      output_tokens: 20,
      cached_tokens: 50,
      cache_creation_tokens: 10
    )

    refute message.as_json.key?("ruby_llm_telemetry")
    assert message.as_json(include_ruby_llm_telemetry: true).key?("ruby_llm_telemetry")
  end

  test "does not describe human messages as RubyLLM calls" do
    message = @chat.messages.create!(role: "user", content: "Hello", user: @user)

    assert_nil message.ruby_llm_telemetry
  end

end
