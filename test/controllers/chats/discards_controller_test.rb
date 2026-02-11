require "test_helper"

class Chats::DiscardsControllerTest < ActionDispatch::IntegrationTest

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

  test "create soft deletes the chat for admin" do
    assert @account.manageable_by?(@user)
    assert_not @chat.discarded?

    post account_chat_discard_path(@account, @chat)

    assert_redirected_to account_chats_path(@account)
    @chat.reload
    assert @chat.discarded?
  end

  test "create creates audit log" do
    assert_difference "AuditLog.count" do
      post account_chat_discard_path(@account, @chat)
    end

    audit = AuditLog.last
    assert_equal "discard_chat", audit.action
    assert_equal @chat.id, audit.auditable_id
  end

  test "create is forbidden for non-admin" do
    team_account = accounts(:team_account)
    member_user = users(:existing_user)
    team_chat = team_account.chats.create!(model_id: "openrouter/auto", title: "Team Chat")

    delete logout_path
    post login_path, params: {
      email_address: member_user.email_address,
      password: "password123"
    }

    assert_not team_account.manageable_by?(member_user)

    post account_chat_discard_path(team_account, team_chat)

    assert_redirected_to account_chats_path(team_account)
    assert_match(/permission/, flash[:alert])
    team_chat.reload
    assert_not team_chat.discarded?
  end

  test "destroy restores a discarded chat for admin" do
    @chat.discard!
    assert @chat.discarded?

    delete account_chat_discard_path(@account, @chat)

    assert_redirected_to account_chats_path(@account)
    @chat.reload
    assert_not @chat.discarded?
  end

  test "destroy creates audit log" do
    @chat.discard!

    assert_difference "AuditLog.count" do
      delete account_chat_discard_path(@account, @chat)
    end

    audit = AuditLog.last
    assert_equal "restore_chat", audit.action
    assert_equal @chat.id, audit.auditable_id
  end

  test "destroy is forbidden for non-admin" do
    team_account = accounts(:team_account)
    member_user = users(:existing_user)
    team_chat = team_account.chats.create!(model_id: "openrouter/auto", title: "Team Chat")
    team_chat.discard!

    delete logout_path
    post login_path, params: {
      email_address: member_user.email_address,
      password: "password123"
    }

    assert_not team_account.manageable_by?(member_user)

    delete account_chat_discard_path(team_account, team_chat)

    assert_redirected_to account_chats_path(team_account)
    assert_match(/permission/, flash[:alert])
    team_chat.reload
    assert team_chat.discarded?
  end

end
