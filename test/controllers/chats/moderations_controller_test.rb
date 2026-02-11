require "test_helper"

class Chats::ModerationsControllerTest < ActionDispatch::IntegrationTest

  setup do
    @admin_user = users(:site_admin_user)
    @admin_account = accounts(:site_admin_account)
    @user = users(:user_1)
    @account = accounts(:personal_account)
  end

  test "create queues moderation for site admin" do
    chat = @admin_account.chats.create!(model_id: "openrouter/auto", title: "Admin Chat")

    post login_path, params: {
      email_address: @admin_user.email_address,
      password: "password123"
    }

    post account_chat_moderation_path(@admin_account, chat),
      headers: { "Accept" => "application/json" }

    assert_response :success
    json = JSON.parse(response.body)
    assert json.key?("queued")
  end

  test "create is forbidden for non-site-admin" do
    chat = @account.chats.create!(model_id: "openrouter/auto", title: "Test Chat")

    post login_path, params: {
      email_address: @user.email_address,
      password: "password123"
    }

    post account_chat_moderation_path(@account, chat)

    assert_redirected_to account_chats_path(@account)
    assert_match(/permission/, flash[:alert])
  end

  test "create creates audit log" do
    chat = @admin_account.chats.create!(model_id: "openrouter/auto", title: "Admin Chat")

    post login_path, params: {
      email_address: @admin_user.email_address,
      password: "password123"
    }

    assert_difference "AuditLog.count" do
      post account_chat_moderation_path(@admin_account, chat),
        headers: { "Accept" => "application/json" }
    end

    audit = AuditLog.last
    assert_equal "moderate_all_messages", audit.action
  end

end
