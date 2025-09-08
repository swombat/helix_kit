require "test_helper"

class GenerateTitleJobTest < ActiveJob::TestCase

  setup do
    @account = accounts(:personal_account)
    @chat = @account.chats.create!(
      model_id: "openrouter/auto"
      # No title - this should be untitled
    )
    @titled_chat = @account.chats.create!(
      model_id: "openrouter/auto",
      title: "Existing Title"
    )
  end

  test "generates title for chat without title" do
    # Create a user message for the chat so title generation can proceed
    @chat.messages.create!(
      content: "Hello, how are you?",
      role: "user",
      user: users(:user_1)
    )

    # Mock the title generation method
    @chat.define_singleton_method(:generate_title) do |content|
      "Generated Title"
    end

    GenerateTitleJob.perform_now(@chat)

    assert_equal "Generated Title", @chat.reload.title
  end

  test "skips chat that already has title" do
    original_title = @titled_chat.title

    # Mock should not be called since chat already has title
    @titled_chat.define_singleton_method(:generate_title) do |content|
      "Should Not Use This"
    end

    GenerateTitleJob.perform_now(@titled_chat)

    assert_equal original_title, @titled_chat.reload.title
  end

  test "skips chat with no user messages" do
    chat_without_messages = @account.chats.create!(
      model_id: "openrouter/auto"
    )

    # Mock should not be called since there are no user messages
    chat_without_messages.define_singleton_method(:generate_title) do |content|
      "Should Not Use This"
    end

    GenerateTitleJob.perform_now(chat_without_messages)

    assert_nil chat_without_messages.reload.title
  end

  test "job is enqueued after chat creation" do
    assert_enqueued_with(job: GenerateTitleJob) do
      Chat.create!(account: accounts(:personal_account))
    end
  end

  test "job is not enqueued when title exists" do
    assert_no_enqueued_jobs(only: GenerateTitleJob) do
      Chat.create!(
        account: accounts(:personal_account),
        title: "Existing Title"
      )
    end
  end

  test "handles empty title response gracefully" do
    # Create a user message for the chat
    @chat.messages.create!(
      content: "Hello, how are you?",
      role: "user",
      user: users(:user_1)
    )

    @chat.define_singleton_method(:generate_title) do |content|
      ""
    end

    GenerateTitleJob.perform_now(@chat)

    assert_nil @chat.reload.title
  end

  test "handles nil title response gracefully" do
    # Create a user message for the chat
    @chat.messages.create!(
      content: "Hello, how are you?",
      role: "user",
      user: users(:user_1)
    )

    @chat.define_singleton_method(:generate_title) do |content|
      nil
    end

    GenerateTitleJob.perform_now(@chat)

    assert_nil @chat.reload.title
  end

end
