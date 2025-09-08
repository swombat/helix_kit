require "test_helper"

class ChatSimpleTest < ActiveSupport::TestCase

  setup do
    @account = accounts(:personal_account)
    @user = users(:user_1)
  end

  test "creates chat with default model" do
    chat = Chat.create!(account: @account)
    assert_equal "openrouter/auto", chat.model_id
    assert_equal @account, chat.account
  end

  test "validates model_id presence" do
    chat = Chat.new(account: @account, model_id: nil)
    assert_not chat.valid?
    assert_includes chat.errors[:model_id], "can't be blank"
  end

  test "creates message with valid attributes" do
    chat = Chat.create!(account: @account)
    message = chat.messages.create!(
      user: @user,
      role: "user",
      content: "Test message"
    )

    assert message.persisted?
    assert_equal "user", message.role
    assert_equal @user, message.user
    assert_equal chat, message.chat
  end

  test "ai message has no user" do
    chat = Chat.create!(account: @account)
    message = chat.messages.create!(
      role: "assistant",
      content: "AI response"
    )

    assert message.persisted?
    assert_equal "assistant", message.role
    assert_nil message.user
  end

  test "includes required concerns" do
    assert Chat.included_modules.include?(Broadcastable)
    assert Chat.included_modules.include?(ObfuscatesId)
    assert Message.included_modules.include?(Broadcastable)
    assert Message.included_modules.include?(ObfuscatesId)
  end

  test "acts as chat and message" do
    chat = Chat.create!(account: @account)
    message = chat.messages.create!(role: "user", content: "Test", user: @user)

    # RubyLLM methods should be available
    assert chat.respond_to?(:ask)
    assert message.respond_to?(:to_llm)
  end

end
