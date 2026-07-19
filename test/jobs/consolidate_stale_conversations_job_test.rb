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

  test "enqueues active regular chats when their transcript exceeds the budget" do
    @regular_chat.messages.create!(
      role: "user",
      content: "This active transcript is deliberately over the test budget.",
      user: @user
    )

    ENV.stub(:fetch, ->(key, default = nil) { key == "HELIX_TRANSCRIPT_BUDGET_TOKENS" ? "1" : ENV[key] || default }) do
      assert_enqueued_with(job: ConsolidateConversationJob, args: [ @regular_chat ]) do
        ConsolidateStaleConversationsJob.perform_now
      end
    end
  end

  test "candidate scan does not assume four bytes per token" do
    @regular_chat.messages.create!(
      role: "user",
      content: "abcdefghij",
      user: @user
    )

    ENV.stub(:fetch, ->(key, default = nil) { key == "HELIX_TRANSCRIPT_BUDGET_TOKENS" ? "5" : ENV[key] || default }) do
      ConsolidateConversationJob.stub(:transcript_over_budget?, true) do
        assert_enqueued_with(job: ConsolidateConversationJob, args: [ @regular_chat ]) do
          ConsolidateStaleConversationsJob.perform_now
        end
      end
    end
  end

  test "does not repeatedly enqueue an over-budget chat without new messages" do
    message = @regular_chat.messages.create!(
      role: "user",
      content: "This transcript remains large after its checkpoint.",
      user: @user
    )
    @regular_chat.update!(
      checkpoint_summary: "Existing checkpoint.",
      last_consolidated_at: 1.hour.ago,
      last_consolidated_message_id: message.id
    )

    ENV.stub(:fetch, ->(key, default = nil) { key == "HELIX_TRANSCRIPT_BUDGET_TOKENS" ? "1" : ENV[key] || default }) do
      assert_no_enqueued_jobs(only: ConsolidateConversationJob) do
        ConsolidateStaleConversationsJob.perform_now
      end
    end
  end

  test "budget check measures the checkpoint plus retained tail instead of all historical rows" do
    historical = 5.times.map do |index|
      @regular_chat.messages.create!(
        role: "user",
        content: "Historical #{index} " + ("large " * 500),
        user: @user
      )
    end
    20.times do |index|
      @regular_chat.messages.create!(role: "user", content: "Recent #{index}", user: @user)
    end
    boundary = @regular_chat.messages.order(:created_at, :id).last
    @regular_chat.update!(
      checkpoint_summary: "Compact checkpoint.",
      last_consolidated_at: 1.hour.ago,
      last_consolidated_message_id: boundary.id
    )
    @regular_chat.messages.create!(role: "user", content: "Tiny new turn", user: @user)

    ENV.stub(:fetch, ->(key, default = nil) { key == "HELIX_TRANSCRIPT_BUDGET_TOKENS" ? "200" : ENV[key] || default }) do
      assert_no_enqueued_jobs(only: ConsolidateConversationJob) do
        ConsolidateStaleConversationsJob.perform_now
      end
    end

    assert historical.all?(&:persisted?)
  end

end
