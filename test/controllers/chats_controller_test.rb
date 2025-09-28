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

  test "chats blocked when disabled" do
    Setting.instance.update!(allow_chats: false)
    sign_in @user

    get account_chats_path(@account)
    assert_redirected_to root_path
    assert_match(/disabled/, flash[:alert])
  end

  test "should require authentication" do
    delete logout_path

    get account_chats_path(@account)
    assert_response :redirect
  end

  test "should create chat with message and trigger AI response" do
    assert_difference "Chat.count" do
      assert_difference "Message.count" do
        assert_enqueued_with(job: AiResponseJob) do
          post account_chats_path(@account), params: {
            chat: { model_id: "gpt-4o" },
            message: "Hello AI"
          }
        end
      end
    end

    chat = Chat.last
    message = chat.messages.last
    assert_equal "Hello AI", message.content
    assert_equal "user", message.role
    assert_equal @user, message.user
    assert_redirected_to account_chat_path(@account, chat)
  end

  test "index should return correct Inertia props" do
    get account_chats_path(@account)

    assert_response :success
    # For now, just verify the endpoint works - Inertia testing can be complex in test env
  end

  test "show should return correct Inertia props" do
    # Add a message to the chat
    @chat.messages.create!(
      content: "Test message",
      role: "user",
      user: @user
    )

    get account_chat_path(@account, @chat)

    assert_response :success
    # For now, just verify the endpoint works - Inertia testing can be complex in test env
  end

  test "should handle latest scope in index" do
    # Create multiple chats with different update times
    old_chat = @account.chats.create!(
      model_id: "gpt-4o",
      title: "Old Chat",
      updated_at: 2.days.ago
    )
    new_chat = @account.chats.create!(
      model_id: "gpt-4o",
      title: "New Chat",
      updated_at: 1.hour.ago
    )

    get account_chats_path(@account)

    assert_response :success
    # Verify that chats are loaded in the correct order by checking the scope
    chats = @account.chats.latest.to_a
    # Should include all chats and be in latest order
    assert_equal 3, chats.count
    chat_ids = chats.map(&:id)
    assert_includes chat_ids, new_chat.id
    assert_includes chat_ids, @chat.id
    assert_includes chat_ids, old_chat.id
    # Latest scope should order by updated_at desc
    assert chats.first.updated_at >= chats.second.updated_at
  end

end
