require "test_helper"

class ChatTest < ActiveSupport::TestCase

  def setup
    @user = User.create!(
      email_address: "test#{SecureRandom.hex(4)}@example.com",
      password: "password123",
      first_name: "Test",
      last_name: "User"
    )
    @account = @user.personal_account
  end

  test "belongs to account" do
    chat = Chat.create!(account: @account)
    assert_equal @account, chat.account
  end

  test "has many messages with destroy dependency" do
    chat = Chat.create!(account: @account)
    message = chat.messages.create!(
      user: @user,
      role: "user",
      content: "Test message"
    )
    message_id = message.id

    chat.destroy!

    assert_not Message.exists?(message_id)
  end

  test "validates model_id presence" do
    chat = Chat.new(account: @account)
    chat.model_id = nil

    assert_not chat.valid?
    assert_includes chat.errors[:model_id], "can't be blank"
  end

  test "defaults model_id to openrouter/auto" do
    chat = Chat.create!(account: @account)
    assert_equal "openrouter/auto", chat.model_id
  end

  test "schedules title generation job after create when no title" do
    assert_enqueued_with(job: GenerateTitleJob) do
      Chat.create!(account: @account)
    end
  end

  test "does not schedule title generation when title exists" do
    assert_no_enqueued_jobs(only: GenerateTitleJob) do
      Chat.create!(account: @account, title: "Existing Title")
    end
  end

  test "includes required concerns" do
    assert Chat.included_modules.include?(Broadcastable)
    assert Chat.included_modules.include?(ObfuscatesId)
  end

  test "acts as chat" do
    chat = Chat.create!(account: @account)
    # RubyLLM methods should be available
    assert chat.respond_to?(:ask)
    # Note: generate_title is not a direct method, it's handled by the job
    assert chat.respond_to?(:to_llm)
  end

  test "broadcasts to account" do
    assert_equal [ :account ], Chat.broadcast_targets
  end

end
