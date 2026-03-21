require "test_helper"

class StreamsAiResponseTest < ActiveSupport::TestCase

  # Lightweight test harness that includes the concern under test.
  # All concern methods are private, so we expose them via public wrappers.
  class StreamingHarness

    include StreamsAiResponse

    attr_accessor :ai_message, :message_finalized

    def initialize
      setup_streaming_state
    end

    # Expose private methods for direct testing
    def call_setup_streaming_state       = setup_streaming_state
    def call_cleanup_partial_message     = cleanup_partial_message
    def call_cleanup_streaming           = cleanup_streaming
    def message_finalized?               = @message_finalized

  end

  setup do
    @account = accounts(:personal_account)
    @chat = @account.chats.create!(
      model_id_string: "openrouter/auto",
      title: "Streaming Cleanup Test"
    )
    @harness = StreamingHarness.new
  end

  # ── setup_streaming_state ──────────────────────────────────────────

  test "setup_streaming_state initializes message_finalized to false" do
    assert_equal false, @harness.message_finalized?
  end

  test "setup_streaming_state resets message_finalized back to false" do
    @harness.message_finalized = true
    assert @harness.message_finalized?

    @harness.call_setup_streaming_state
    assert_equal false, @harness.message_finalized?
  end

  # ── cleanup_partial_message ────────────────────────────────────────

  test "cleanup_partial_message destroys un-finalized message with partial content" do
    message = @chat.messages.create!(
      role: "assistant",
      content: "partial streaming content that was never finalized",
      streaming: true
    )
    @harness.ai_message = message

    assert_difference "Message.count", -1 do
      @harness.call_cleanup_partial_message
    end

    assert_not Message.exists?(message.id)
    assert_nil @harness.ai_message
  end

  test "cleanup_partial_message destroys un-finalized message with empty content" do
    message = @chat.messages.create!(
      role: "assistant",
      content: "",
      streaming: true
    )
    @harness.ai_message = message

    assert_difference "Message.count", -1 do
      @harness.call_cleanup_partial_message
    end

    assert_not Message.exists?(message.id)
    assert_nil @harness.ai_message
  end

  test "cleanup_partial_message preserves finalized message" do
    message = @chat.messages.create!(
      role: "assistant",
      content: "Fully finalized response with tokens",
      model_id_string: "anthropic/claude-sonnet-4-20250514",
      output_tokens: 42
    )
    @harness.ai_message = message
    @harness.message_finalized = true

    assert_no_difference "Message.count" do
      @harness.call_cleanup_partial_message
    end

    assert Message.exists?(message.id)
    assert_equal message, @harness.ai_message
  end

  test "cleanup_partial_message does nothing when ai_message is nil" do
    @harness.ai_message = nil

    assert_no_difference "Message.count" do
      @harness.call_cleanup_partial_message
    end
  end

  test "cleanup_partial_message does nothing when ai_message is not persisted" do
    # Build an in-memory message that has never been saved
    unsaved_message = @chat.messages.build(role: "assistant", content: "")
    @harness.ai_message = unsaved_message

    assert_no_difference "Message.count" do
      @harness.call_cleanup_partial_message
    end
  end

  # ── cleanup_streaming ──────────────────────────────────────────────

  test "cleanup_streaming does not error when ai_message was already destroyed" do
    message = @chat.messages.create!(
      role: "assistant",
      content: "will be destroyed",
      streaming: true
    )
    @harness.ai_message = message

    # Destroy the message out-of-band (simulating another process cleaning it up)
    message.destroy

    # The persisted? check should prevent calling stop_streaming on a destroyed record
    assert_nothing_raised do
      @harness.call_cleanup_streaming
    end
  end

  test "cleanup_streaming does not error when ai_message is nil" do
    @harness.ai_message = nil

    assert_nothing_raised do
      @harness.call_cleanup_streaming
    end
  end

  test "cleanup_streaming stops streaming on a persisted streaming message" do
    message = @chat.messages.create!(
      role: "assistant",
      content: "streaming in progress",
      streaming: true
    )
    @harness.ai_message = message

    assert message.streaming?

    @harness.call_cleanup_streaming

    message.reload
    assert_not message.streaming?
  end

end
