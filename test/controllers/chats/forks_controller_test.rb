require "test_helper"

class Chats::ForksControllerTest < ActionDispatch::IntegrationTest

  setup do
    @user = users(:user_1)
    @account = accounts(:personal_account)
    @chat = @account.chats.create!(
      model_id: "openrouter/auto",
      title: "Test Conversation"
    )

    post login_path, params: {
      email_address: @user.email_address,
      password: "password123"
    }
    assert_redirected_to root_path
  end

  test "create forks the chat with custom title" do
    assert_difference "Chat.count" do
      post account_chat_fork_path(@account, @chat), params: { title: "My Fork" }
    end

    forked_chat = Chat.last
    assert_equal "My Fork", forked_chat.title
    assert_redirected_to account_chat_path(@account, forked_chat)
  end

  test "create forks the chat with default title when none provided" do
    assert_difference "Chat.count" do
      post account_chat_fork_path(@account, @chat)
    end

    forked_chat = Chat.last
    assert_match(/Fork/, forked_chat.title)
    assert_redirected_to account_chat_path(@account, forked_chat)
  end

  test "create creates audit log" do
    assert_difference "AuditLog.count" do
      post account_chat_fork_path(@account, @chat), params: { title: "My Fork" }
    end

    audit = AuditLog.last
    assert_equal "fork_chat", audit.action
    assert_equal @chat.id, audit.data["source_chat_id"]
  end

  test "requires authentication" do
    delete logout_path

    post account_chat_fork_path(@account, @chat)
    assert_response :redirect
  end

end
