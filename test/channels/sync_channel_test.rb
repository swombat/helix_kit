require "test_helper"

class SyncChannelTest < ActionCable::Channel::TestCase

  def setup
    @user = users(:user_1)
    @admin = users(:site_admin_user)
    @account = accounts(:personal_account)
  end

  test "subscribes to accessible account" do
    stub_connection current_user: @user
    subscribe channel: "SyncChannel", model: "Account", id: @account.obfuscated_id

    assert subscription.confirmed?
    assert_has_stream "Account:#{@account.obfuscated_id}"
  end

  test "rejects inaccessible account" do
    other_user = users(:existing_user)
    other_account = accounts(:existing_user_account)

    stub_connection current_user: @user
    subscribe channel: "SyncChannel", model: "Account", id: other_account.obfuscated_id

    assert subscription.rejected?
  end

  test "admin can subscribe to all accounts" do
    stub_connection current_user: @admin
    subscribe channel: "SyncChannel", model: "Account", id: "all"

    assert subscription.confirmed?
    assert_has_stream "Account:all"
  end

  test "non-admin cannot subscribe to all accounts" do
    stub_connection current_user: @user
    subscribe channel: "SyncChannel", model: "Account", id: "all"

    assert subscription.rejected?
  end

  test "rejects invalid model class" do
    stub_connection current_user: @user
    subscribe channel: "SyncChannel", model: "InvalidModel", id: "test"

    assert subscription.rejected?
  end

  test "rejects subscription without model param" do
    stub_connection current_user: @user
    subscribe channel: "SyncChannel", id: "test"

    assert subscription.rejected?
  end

  # Tests for deliver_current_state_if_streaming

  test "transmits current state when subscribing to streaming message" do
    chat = Chat.create!(account: @account)
    message = chat.messages.create!(
      role: "assistant",
      content: "Hello, world!",
      streaming: true
    )
    message.update_column(:thinking_text, "Some thinking")

    stub_connection current_user: @user
    subscribe channel: "SyncChannel", model: "Message", id: message.obfuscated_id

    assert subscription.confirmed?
    assert_has_stream "Message:#{message.obfuscated_id}"

    assert_equal 1, transmissions.size
    transmission = transmissions.first
    assert_equal "current_state", transmission["action"]
    assert_equal message.obfuscated_id, transmission["id"]
    assert_equal "Hello, world!", transmission["content"]
    assert_equal "Some thinking", transmission["thinking"]
  end

  test "does not transmit current state when subscribing to non-streaming message" do
    chat = Chat.create!(account: @account)
    message = chat.messages.create!(
      role: "assistant",
      content: "Hello, world!",
      streaming: false
    )

    stub_connection current_user: @user
    subscribe channel: "SyncChannel", model: "Message", id: message.obfuscated_id

    assert subscription.confirmed?
    assert_has_stream "Message:#{message.obfuscated_id}"

    assert_equal 0, transmissions.size
  end

  test "does not transmit current state when subscribing to non-Message model" do
    stub_connection current_user: @user
    subscribe channel: "SyncChannel", model: "Account", id: @account.obfuscated_id

    assert subscription.confirmed?
    assert_has_stream "Account:#{@account.obfuscated_id}"

    assert_equal 0, transmissions.size
  end

  test "transmits correct content and thinking fields for streaming message" do
    chat = Chat.create!(account: @account)
    message = chat.messages.create!(
      role: "assistant",
      content: "Partial response...",
      streaming: true
    )
    message.update_column(:thinking_text, "I am considering the question")

    stub_connection current_user: @user
    subscribe channel: "SyncChannel", model: "Message", id: message.obfuscated_id

    assert_equal 1, transmissions.size
    transmission = transmissions.first

    assert_equal "Partial response...", transmission["content"]
    assert_equal "I am considering the question", transmission["thinking"]
  end

  test "transmits nil thinking when message has no thinking" do
    chat = Chat.create!(account: @account)
    message = chat.messages.create!(
      role: "assistant",
      content: "Response without thinking",
      streaming: true
    )

    stub_connection current_user: @user
    subscribe channel: "SyncChannel", model: "Message", id: message.obfuscated_id

    assert_equal 1, transmissions.size
    transmission = transmissions.first

    assert_equal "Response without thinking", transmission["content"]
    assert_nil transmission["thinking"]
  end

end
