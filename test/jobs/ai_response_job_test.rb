require "test_helper"
require "ostruct"

class AiResponseJobTest < ActiveJob::TestCase

  setup do
    # Create test data instead of using fixtures
    @user = users(:user_1)
    @account = accounts(:personal_account)
    @chat = @account.chats.create!(
      model_id: "openrouter/auto",
      title: "Test Conversation"
    )
    @user_message = @chat.messages.create!(
      content: "Hello, how are you?",
      role: "user",
      user: @user
    )
  end

  test "streams content and finalizes message" do
    # Create the AI message first (as the real flow would)
    ai_message = @chat.messages.create!(
      role: "assistant",
      content: ""
    )

    # Mock the streaming response
    mock_chunks = [
      OpenStruct.new(content: "Hello"),
      OpenStruct.new(content: ", "),
      OpenStruct.new(content: "how can I help?")
    ]

    # Override the complete method for this test
    @chat.define_singleton_method(:complete) do |&block|
      # Simulate on_new_message callback
      @on_new_message_callback&.call

      # Simulate streaming chunks
      mock_chunks.each { |chunk| block.call(chunk) }

      # Simulate on_end_message callback
      final_message = OpenStruct.new(
        content: "Hello, how can I help?",
        model_id: "test-model",
        input_tokens: 10,
        output_tokens: 15
      )
      @on_end_message_callback&.call(final_message)
    end

    @chat.define_singleton_method(:on_new_message) do |&block|
      @on_new_message_callback = block
    end

    @chat.define_singleton_method(:on_end_message) do |&block|
      @on_end_message_callback = block
    end

    # Run the job
    AiResponseJob.perform_now(@chat, @user_message)

    # Check the final result
    ai_message.reload
    assert_equal "Hello, how can I help?", ai_message.content
    assert_not ai_message.streaming?  # Should be false after finalization
    assert_equal "test-model", ai_message.model_id
    assert_equal 10, ai_message.input_tokens
    assert_equal 15, ai_message.output_tokens
  end

  test "handles empty chunks gracefully" do
    mock_chunks = [
      OpenStruct.new(content: nil),
      OpenStruct.new(content: "Valid content"),
      OpenStruct.new(content: "")
    ]

    # Override the complete method for this test
    @chat.define_singleton_method(:complete) do |&block|
      @on_new_message_callback&.call
      mock_chunks.each { |chunk| block.call(chunk) }

      final_message = OpenStruct.new(
        content: "Valid content",
        model_id: "test-model",
        input_tokens: 5,
        output_tokens: 10
      )
      @on_end_message_callback&.call(final_message)
    end

    @chat.define_singleton_method(:on_new_message) do |&block|
      @on_new_message_callback = block
    end

    @chat.define_singleton_method(:on_end_message) do |&block|
      @on_end_message_callback = block
    end

    AiResponseJob.perform_now(@chat, @user_message)

    ai_message = Message.last
    assert_equal "Valid content", ai_message.content
  end

  test "job is enqueued properly" do
    assert_enqueued_with(job: AiResponseJob, args: [ @chat, @user_message ]) do
      AiResponseJob.perform_later(@chat, @user_message)
    end
  end

  test "sets streaming to false in finalize_message" do
    mock_chunks = [
      OpenStruct.new(content: "Hello"),
      OpenStruct.new(content: ", "),
      OpenStruct.new(content: "how can I help?")
    ]

    # Override the complete method to simulate streaming and finalization
    @chat.define_singleton_method(:complete) do |&block|
      # Simulate on_new_message callback
      @on_new_message_callback&.call

      # Simulate streaming chunks
      mock_chunks.each { |chunk| block.call(chunk) }

      # Simulate on_end_message callback
      final_message = OpenStruct.new(
        content: "Hello, how can I help?",
        model_id: "test-model",
        input_tokens: 10,
        output_tokens: 15
      )
      @on_end_message_callback&.call(final_message)
    end

    # Mock callback registration
    @chat.define_singleton_method(:on_new_message) do |&block|
      @on_new_message_callback = block
    end

    @chat.define_singleton_method(:on_end_message) do |&block|
      @on_end_message_callback = block
    end

    AiResponseJob.perform_now(@chat, @user_message)

    ai_message = Message.last
    assert_equal "Hello, how can I help?", ai_message.content
    assert_not ai_message.streaming?  # Should be false after finalization
  end

  test "handles job failure gracefully" do
    # Create an AI message that will be streaming
    ai_message = @chat.messages.create!(
      role: "assistant",
      content: "",
      streaming: true
    )

    # Override the complete method to raise an error
    @chat.define_singleton_method(:complete) do |&block|
      @on_new_message_callback&.call
      raise "Simulated error"
    end

    @chat.define_singleton_method(:on_new_message) do |&block|
      @on_new_message_callback = block
    end

    @chat.define_singleton_method(:on_end_message) do |&block|
      @on_end_message_callback = block
    end

    # The job should handle the error but still stop streaming
    assert_raises(RuntimeError, "Simulated error") do
      AiResponseJob.perform_now(@chat, @user_message)
    end

    # The message should no longer be streaming after the error
    ai_message.reload
    assert_not ai_message.streaming?
  end

end
