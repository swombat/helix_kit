require "test_helper"

class RubyLlmIntegrationTest < ActiveSupport::TestCase

  # Don't load fixtures - create our own data
  self.use_transactional_tests = true

  setup do
    # Create test data manually
    @user = User.create!(
      email_address: "test@rubyllm.com",
      password: "password123",
      password_confirmation: "password123",
      first_name: "Test",
      last_name: "User"
    )

    @account = Account.create!(
      name: "Test Account",
      account_type: :personal
    )

    # Create account user relationship
    @account.account_users.create!(
      user: @user,
      role: "owner",
      skip_confirmation: true
    )
  end

  test "Chat model basic functionality" do
    chat = Chat.create!(account: @account)

    assert_equal "openrouter/auto", chat.model_id
    assert_equal @account, chat.account
    assert chat.respond_to?(:ask)
    assert chat.respond_to?(:generate_title)
    assert Chat.included_modules.include?(Broadcastable)
    assert Chat.included_modules.include?(ObfuscatesId)
  end

  test "Message model basic functionality" do
    chat = Chat.create!(account: @account)

    # Test user message
    user_message = chat.messages.create!(
      user: @user,
      role: "user",
      content: "Hello AI"
    )

    assert user_message.persisted?
    assert_equal "user", user_message.role
    assert_equal @user, user_message.user
    assert_equal chat, user_message.chat
    assert user_message.respond_to?(:to_openai)

    # Test AI message
    ai_message = chat.messages.create!(
      role: "assistant",
      content: "Hello! How can I help?"
    )

    assert ai_message.persisted?
    assert_equal "assistant", ai_message.role
    assert_nil ai_message.user
    assert Message.included_modules.include?(Broadcastable)
    assert Message.included_modules.include?(ObfuscatesId)
  end

  test "Chat validation" do
    chat = Chat.new(account: @account, model_id: nil)
    assert_not chat.valid?
    assert_includes chat.errors[:model_id], "can't be blank"
  end

  test "Message validation" do
    chat = Chat.create!(account: @account)

    # Test role validation
    message = Message.new(chat: chat, user: @user, content: "Test")
    message.role = "invalid"
    assert_not message.valid?
    assert_includes message.errors[:role], "is not included in the list"

    # Test content validation
    message.role = "user"
    message.content = ""
    assert_not message.valid?
    assert_includes message.errors[:content], "can't be blank"
  end

  test "Chat destroys messages" do
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

  test "GenerateTitleJob is enqueued on chat creation without title" do
    assert_enqueued_with(job: GenerateTitleJob) do
      Chat.create!(account: @account)
    end
  end

  test "GenerateTitleJob is not enqueued when title exists" do
    assert_no_enqueued_jobs(only: GenerateTitleJob) do
      Chat.create!(account: @account, title: "Existing Title")
    end
  end

end
