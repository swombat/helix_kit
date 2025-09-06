require "test_helper"

class GenerateTitleJobTest < ActiveJob::TestCase

  setup do
    @chat = chats(:untitled_chat)
    @titled_chat = chats(:conversation)
  end

  test "generates title for chat without title" do
    # Mock the title generation
    @chat.stub(:generate_title, "Generated Title") do
      GenerateTitleJob.perform_now(@chat)
    end

    assert_equal "Generated Title", @chat.reload.title
  end

  test "skips chat that already has title" do
    original_title = @titled_chat.title

    @titled_chat.stub(:generate_title, "Should Not Use This") do
      GenerateTitleJob.perform_now(@titled_chat)
    end

    assert_equal original_title, @titled_chat.reload.title
  end

  test "skips chat with no user messages" do
    chat_without_messages = Chat.create!(
      account: accounts(:personal_account),
      model_id: "openrouter/auto"
    )

    chat_without_messages.stub(:generate_title, "Should Not Use This") do
      GenerateTitleJob.perform_now(chat_without_messages)
    end

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
    @chat.stub(:generate_title, "") do
      GenerateTitleJob.perform_now(@chat)
    end

    assert_nil @chat.reload.title
  end

  test "handles nil title response gracefully" do
    @chat.stub(:generate_title, nil) do
      GenerateTitleJob.perform_now(@chat)
    end

    assert_nil @chat.reload.title
  end

end
