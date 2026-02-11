require "test_helper"

class Chats::ArchivesControllerTest < ActionDispatch::IntegrationTest

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

  test "create archives the chat" do
    assert_not @chat.archived?

    post account_chat_archive_path(@account, @chat)

    assert_redirected_to account_chats_path(@account)
    @chat.reload
    assert @chat.archived?
  end

  test "create creates audit log" do
    assert_difference "AuditLog.count" do
      post account_chat_archive_path(@account, @chat)
    end

    audit = AuditLog.last
    assert_equal "archive_chat", audit.action
    assert_equal @chat.id, audit.auditable_id
  end

  test "destroy unarchives the chat" do
    @chat.archive!
    assert @chat.archived?

    delete account_chat_archive_path(@account, @chat)

    assert_redirected_to account_chats_path(@account)
    @chat.reload
    assert_not @chat.archived?
  end

  test "destroy creates audit log" do
    @chat.archive!

    assert_difference "AuditLog.count" do
      delete account_chat_archive_path(@account, @chat)
    end

    audit = AuditLog.last
    assert_equal "unarchive_chat", audit.action
    assert_equal @chat.id, audit.auditable_id
  end

  test "requires authentication" do
    delete logout_path

    post account_chat_archive_path(@account, @chat)
    assert_response :redirect
  end

  test "scopes to current account" do
    other_user = User.create!(email_address: "archiveother@example.com")
    other_user.profile.update!(first_name: "Other", last_name: "User")
    other_account = other_user.personal_account
    other_chat = other_account.chats.create!(model_id: "openrouter/auto")

    post account_chat_archive_path(@account, other_chat)
    assert_response :not_found
  end

end
