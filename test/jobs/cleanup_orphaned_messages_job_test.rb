require "test_helper"

class CleanupOrphanedMessagesJobTest < ActiveJob::TestCase

  setup do
    @account = accounts(:personal_account)
    @user = users(:user_1)
    @chat = @account.chats.create!(
      model_id_string: "openrouter/auto",
      title: "Cleanup Test Chat"
    )
  end

  test "deletes orphaned assistant messages" do
    # Create an orphaned message (no model_id_string, no output_tokens, not streaming)
    orphan = @chat.messages.create!(
      role: "assistant",
      content: "orphaned response",
      model_id_string: nil,
      output_tokens: nil,
      streaming: false
    )

    assert_difference "Message.count", -1 do
      CleanupOrphanedMessagesJob.perform_now
    end

    assert_not Message.exists?(orphan.id)
  end

  test "skips messages that are currently streaming" do
    streaming_message = @chat.messages.create!(
      role: "assistant",
      content: "still streaming...",
      model_id_string: nil,
      output_tokens: nil,
      streaming: true
    )

    assert_no_difference "Message.count" do
      CleanupOrphanedMessagesJob.perform_now
    end

    assert Message.exists?(streaming_message.id)
  end

  test "skips finalized assistant messages" do
    finalized = @chat.messages.create!(
      role: "assistant",
      content: "completed response",
      model_id_string: "anthropic/claude-sonnet-4-20250514",
      output_tokens: 150,
      streaming: false
    )

    assert_no_difference "Message.count" do
      CleanupOrphanedMessagesJob.perform_now
    end

    assert Message.exists?(finalized.id)
  end

  test "skips user messages" do
    user_msg = @chat.messages.create!(
      role: "user",
      content: "hello",
      user: @user,
      model_id_string: nil,
      output_tokens: nil,
      streaming: false
    )

    assert_no_difference "Message.count" do
      CleanupOrphanedMessagesJob.perform_now
    end

    assert Message.exists?(user_msg.id)
  end

  test "skips assistant messages with model_id_string set" do
    partial = @chat.messages.create!(
      role: "assistant",
      content: "has model but no tokens",
      model_id_string: "anthropic/claude-sonnet-4-20250514",
      output_tokens: nil,
      streaming: false
    )

    assert_no_difference "Message.count" do
      CleanupOrphanedMessagesJob.perform_now
    end

    assert Message.exists?(partial.id)
  end

  test "does nothing when no orphans exist" do
    @chat.messages.create!(
      role: "assistant",
      content: "good message",
      model_id_string: "anthropic/claude-sonnet-4-20250514",
      output_tokens: 100,
      streaming: false
    )

    assert_no_difference "Message.count" do
      CleanupOrphanedMessagesJob.perform_now
    end
  end

  test "cleans up multiple orphaned messages" do
    3.times do |i|
      @chat.messages.create!(
        role: "assistant",
        content: "orphan #{i}",
        model_id_string: nil,
        output_tokens: nil,
        streaming: false
      )
    end

    assert_difference "Message.count", -3 do
      CleanupOrphanedMessagesJob.perform_now
    end
  end

end
