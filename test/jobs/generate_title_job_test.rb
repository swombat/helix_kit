require "test_helper"
require "support/vcr_setup"
require "ostruct"

class GenerateTitleJobTest < ActiveSupport::TestCase

  setup do
    @account = accounts(:personal_account)
  end

  test "generates concise title for chat" do
    chat = build_chat_with_conversation(model_id: "openai/gpt-5-mini")

    VCR.use_cassette("generate_title_job/creates_title") do
      GenerateTitleJob.perform_now(chat)
    end

    assert_equal "Q4 marketing campaign", chat.reload.title
  end

  test "skips chat that already has a title" do
    chat = @account.chats.create!(model_id: "openai/gpt-5-mini", title: "Existing Title")

    assert_no_changes -> { chat.reload.title } do
      GenerateTitleJob.perform_now(chat)
    end
  end

  test "skips chat with no user messages" do
    chat = @account.chats.create!(model_id: "openai/gpt-5-mini")
    chat.messages.create!(role: "assistant", content: "Welcome! How can I help?")

    GenerateTitleJob.perform_now(chat)

    assert_nil chat.reload.title
  end

  test "does not update when prompt returns blank" do
    chat = build_chat_with_conversation(model_id: "openai/gpt-5-mini")

    GenerateTitlePrompt.stub(:new, ->(*) { OpenStruct.new(generate_title: nil) }) do
      GenerateTitleJob.perform_now(chat)
    end

    assert_nil chat.reload.title
  end

  test "enqueues job after chat creation" do
    assert_enqueued_with(job: GenerateTitleJob) do
      @account.chats.create!(model_id: "openai/gpt-5-mini")
    end
  end

  test "does not enqueue job when title is preset" do
    assert_no_enqueued_jobs(only: GenerateTitleJob) do
      @account.chats.create!(model_id: "openai/gpt-5-mini", title: "Preset")
    end
  end

  private

  def build_chat_with_conversation(model_id:)
    chat = @account.chats.create!(model_id: model_id)

    chat.messages.create!(role: "user", content: "We need to plan our Q4 marketing campaign focused on the new product release and social media push.")
    chat.messages.create!(role: "assistant", content: "Let's outline goals, timelines, and assign channel owners so we can launch smoothly.")
    chat.messages.create!(role: "user", content: "Great, please coordinate with design for refreshed assets and confirm the Monday kickoff.")

    chat
  end

end
