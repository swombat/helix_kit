require "test_helper"

class ConsolidateStaleConversationsJobTest < ActiveJob::TestCase

  setup do
    @account = accounts(:personal_account)
    @agent = agents(:research_assistant)
    @user = users(:user_1)

    # Create a group chat with an agent
    @group_chat = @account.chats.new(
      model_id: "openrouter/auto",
      title: "Test Group Chat",
      manual_responses: true
    )
    @group_chat.agent_ids = [ @agent.id ]
    @group_chat.save!

    # Create a regular (non-group) chat
    @regular_chat = @account.chats.create!(
      model_id: "openrouter/auto",
      title: "Regular Chat",
      manual_responses: false
    )
  end

  test "enqueues consolidation for idle group chats" do
    # Create old messages (7 hours ago)
    travel_to 7.hours.ago do
      @group_chat.messages.create!(role: "user", content: "Hello", user: @user)
    end

    travel_back

    assert_enqueued_with(job: ConsolidateConversationJob, args: [ @group_chat ]) do
      ConsolidateStaleConversationsJob.perform_now
    end
  end

  test "skips recently active chats" do
    # Create old messages
    travel_to 7.hours.ago do
      @group_chat.messages.create!(role: "user", content: "Old message", user: @user)
    end
    travel_back

    # Add recent message
    @group_chat.messages.create!(role: "user", content: "New message", user: @user)

    assert_no_enqueued_jobs(only: ConsolidateConversationJob) do
      ConsolidateStaleConversationsJob.perform_now
    end
  end

  test "skips non-group chats" do
    # Create old messages in regular chat
    travel_to 7.hours.ago do
      @regular_chat.messages.create!(role: "user", content: "Old", user: @user)
    end
    travel_back

    # Should not enqueue for regular chat
    assert_no_enqueued_jobs(only: ConsolidateConversationJob) do
      ConsolidateStaleConversationsJob.perform_now
    end
  end

  test "skips already consolidated chats with no new messages" do
    # Create old messages
    travel_to 7.hours.ago do
      @group_chat.messages.create!(role: "user", content: "Hello", user: @user)
    end
    travel_back

    # Mark as already consolidated
    @group_chat.update!(
      last_consolidated_at: 1.hour.ago,
      last_consolidated_message_id: @group_chat.messages.last.id
    )

    assert_no_enqueued_jobs(only: ConsolidateConversationJob) do
      ConsolidateStaleConversationsJob.perform_now
    end
  end

  test "includes previously consolidated chats with new messages" do
    # Create first batch of old messages
    travel_to 10.hours.ago do
      @group_chat.messages.create!(role: "user", content: "First message", user: @user)
    end

    # Mark as consolidated
    @group_chat.update!(
      last_consolidated_at: 8.hours.ago,
      last_consolidated_message_id: @group_chat.messages.first.id
    )

    # Add new old message (still idle, but after consolidation)
    travel_to 7.hours.ago do
      @group_chat.messages.create!(role: "user", content: "Second message", user: @user)
    end
    travel_back

    assert_enqueued_with(job: ConsolidateConversationJob, args: [ @group_chat ]) do
      ConsolidateStaleConversationsJob.perform_now
    end
  end

  test "skips chats with no messages" do
    # Group chat exists but has no messages
    assert_no_enqueued_jobs(only: ConsolidateConversationJob) do
      ConsolidateStaleConversationsJob.perform_now
    end
  end

end
