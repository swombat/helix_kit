require "test_helper"

class RubyLlmIntegrationTest < ActiveSupport::TestCase

  test "Chat model basic functionality" do
    # Create test user and account like other tests do
    email = "chat-test-#{SecureRandom.hex(4)}@example.com"
    user = User.register!(email)
    account = user.personal_account

    chat = Chat.create!(account: account)

    assert_equal "openrouter/auto", chat.model_id
    assert_equal account, chat.account
    assert chat.respond_to?(:ask)
    assert Chat.included_modules.include?(Broadcastable)
    assert Chat.included_modules.include?(ObfuscatesId)
  end

  test "Message model basic functionality" do
    email = "message-test-#{SecureRandom.hex(4)}@example.com"
    user = User.register!(email)
    account = user.personal_account
    chat = Chat.create!(account: account)

    # Test user message
    user_message = chat.messages.create!(
      user: user,
      role: "user",
      content: "Hello AI"
    )

    assert user_message.persisted?
    assert_equal "user", user_message.role
    assert_equal user, user_message.user
    assert_equal chat, user_message.chat
    assert user_message.respond_to?(:to_llm)

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
    email = "validation-test-#{SecureRandom.hex(4)}@example.com"
    user = User.register!(email)
    account = user.personal_account

    chat = Chat.new(account: account, model_id: nil)
    assert_not chat.valid?
    assert_includes chat.errors[:model_id], "can't be blank"
  end

  test "Message validation" do
    email = "msg-validation-#{SecureRandom.hex(4)}@example.com"
    user = User.register!(email)
    account = user.personal_account
    chat = Chat.create!(account: account)

    # Test role validation
    message = Message.new(chat: chat, user: user, content: "Test")
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
    email = "destroy-test-#{SecureRandom.hex(4)}@example.com"
    user = User.register!(email)
    account = user.personal_account
    chat = Chat.create!(account: account)

    message = chat.messages.create!(
      user: user,
      role: "user",
      content: "Test message"
    )
    message_id = message.id

    chat.destroy!

    assert_not Message.exists?(message_id)
  end

  test "GenerateTitleJob is enqueued on chat creation without title" do
    email = "title-job-#{SecureRandom.hex(4)}@example.com"
    user = User.register!(email)
    account = user.personal_account

    assert_enqueued_with(job: GenerateTitleJob) do
      Chat.create!(account: account)
    end
  end

  test "GenerateTitleJob is not enqueued when title exists" do
    email = "no-title-job-#{SecureRandom.hex(4)}@example.com"
    user = User.register!(email)
    account = user.personal_account

    assert_no_enqueued_jobs(only: GenerateTitleJob) do
      Chat.create!(account: account, title: "Existing Title")
    end
  end

end
