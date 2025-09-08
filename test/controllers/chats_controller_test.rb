require "test_helper"

class ChatsControllerTest < ActionDispatch::IntegrationTest

  setup do
    @user = users(:user_1)
    @account = accounts(:personal_account)
    @chat = @account.chats.create!(
      model_id: "openrouter/auto",
      title: "Test Conversation"
    )

    # Sign in user
    post login_path, params: {
      email_address: @user.email_address,
      password: "password123"
    }
    assert_redirected_to root_path
  end

  test "should get index" do
    get account_chats_path(@account)
    assert_response :success
  end

  test "should show chat" do
    get account_chat_path(@account, @chat)
    assert_response :success
  end

  test "should create chat with default model" do
    assert_difference "Chat.count" do
      post account_chats_path(@account)
    end

    chat = Chat.last
    assert_equal "openrouter/auto", chat.model_id
    assert_equal @account, chat.account
    assert_redirected_to account_chat_path(@account, chat)
  end

  test "should create chat with custom model" do
    assert_difference "Chat.count" do
      post account_chats_path(@account), params: {
        chat: { model_id: "gpt-4o" }
      }
    end

    chat = Chat.last
    assert_equal "gpt-4o", chat.model_id
  end

  test "should destroy chat" do
    assert_difference "Chat.count", -1 do
      delete account_chat_path(@account, @chat)
    end

    assert_redirected_to account_chats_path(@account)
  end

  test "should scope chats to current account" do
    # Create a completely separate user and account
    other_user = User.create!(email_address: "other@example.com")
    other_user.profile.update!(first_name: "Other", last_name: "User")
    other_account = other_user.personal_account
    other_chat = other_account.chats.create!(
      model_id: "gpt-4o",
      title: "Other Account Chat"
    )

    # Debug: Check if manual scoping works
    assert_raises(ActiveRecord::RecordNotFound) do
      @account.chats.find(other_chat.id)
    end

    # Now test the controller - should return 404 when chat doesn't belong to account
    get account_chat_path(@account, other_chat)
    assert_response :not_found
  end

  test "should require authentication" do
    delete logout_path

    get account_chats_path(@account)
    assert_response :redirect
  end

end
