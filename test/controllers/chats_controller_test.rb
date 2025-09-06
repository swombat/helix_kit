require "test_helper"

class ChatsControllerTest < ActionDispatch::IntegrationTest

  setup do
    @user = users(:user_1)
    @account = accounts(:personal_account)
    @chat = chats(:conversation)

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
    other_account = accounts(:team_account)
    other_chat = chats(:gpt_chat)

    assert_raises(ActiveRecord::RecordNotFound) do
      get account_chat_path(@account, other_chat)
    end
  end

  test "should require authentication" do
    delete logout_path

    get account_chats_path(@account)
    assert_response :redirect
  end

end
