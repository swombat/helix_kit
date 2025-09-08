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

  test "creates AI message and streams content" do
    # Mock the streaming response
    mock_chunks = [
      OpenStruct.new(content: "Hello"),
      OpenStruct.new(content: ", "),
      OpenStruct.new(content: "how can I help?")
    ]

    # Override the ask method for this test
    @chat.define_singleton_method(:ask) do |content, &block|
      mock_chunks.each { |chunk| block.call(chunk) }
    end

    assert_difference "Message.count" do
      AiResponseJob.perform_now(@chat, @user_message)
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

    # Override the ask method for this test
    @chat.define_singleton_method(:ask) do |content, &block|
      mock_chunks.each { |chunk| block.call(chunk) }
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

end
