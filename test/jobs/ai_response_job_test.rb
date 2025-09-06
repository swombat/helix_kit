require "test_helper"

class AiResponseJobTest < ActiveJob::TestCase

  setup do
    # Mock RubyLLM to avoid actual API calls in tests
    @chat = chats(:conversation)
    @user_message = messages(:user_message)
  end

  test "creates AI message and streams content" do
    # Mock the streaming response
    mock_chunks = [
      OpenStruct.new(content: "Hello"),
      OpenStruct.new(content: ", "),
      OpenStruct.new(content: "how can I help?")
    ]

    @chat.stub(:ask, ->(content, &block) {
      mock_chunks.each { |chunk| block.call(chunk) }
    }) do
      assert_difference "Message.count" do
        AiResponseJob.perform_now(@chat, @user_message)
      end
    end

    ai_message = Message.last
    assert_equal "assistant", ai_message.role
    assert_equal "Hello, how can I help?", ai_message.content
    assert_nil ai_message.user
    assert_equal @chat, ai_message.chat
  end

  test "handles empty chunks gracefully" do
    mock_chunks = [
      OpenStruct.new(content: nil),
      OpenStruct.new(content: "Valid content"),
      OpenStruct.new(content: "")
    ]

    @chat.stub(:ask, ->(content, &block) {
      mock_chunks.each { |chunk| block.call(chunk) }
    }) do
      AiResponseJob.perform_now(@chat, @user_message)
    end

    ai_message = Message.last
    assert_equal "Valid content", ai_message.content
  end

  test "job is enqueued properly" do
    assert_enqueued_with(job: AiResponseJob, args: [ @chat, @user_message ]) do
      AiResponseJob.perform_later(@chat, @user_message)
    end
  end

end
