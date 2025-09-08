require "test_helper"

class MessagesControllerTest < ActionDispatch::IntegrationTest

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

  test "should create message and trigger AI response" do
    assert_difference "Message.count" do
      assert_enqueued_with(job: AiResponseJob) do
        post account_chat_messages_path(@account, @chat), params: {
          message: { content: "Hello AI" }
        }
      end
    end

    message = Message.last
    assert_equal "Hello AI", message.content
    assert_equal "user", message.role
    assert_equal @user, message.user
    assert_equal @chat, message.chat

    assert_redirected_to account_chat_path(@account, @chat)
  end

  test "should handle file attachments" do
    file = fixture_file_upload("test_image.png", "image/png")

    assert_difference "Message.count" do
      post account_chat_messages_path(@account, @chat), params: {
        message: { content: "Here's an image" },
        files: [ file ]
      }
    end

    message = Message.last
    assert message.files.attached?
    assert_equal 1, message.files.count
  end

  test "should scope to current account" do
    # Create a completely separate user and account
    other_user = User.create!(
      email_address: "msgother@example.com"
    )
    other_user.profile.update!(first_name: "Other", last_name: "User")
    other_account = other_user.personal_account
    other_chat = other_account.chats.create!(
      model_id: "gpt-4o",
      title: "Other Account Chat"
    )

    # Should return 404 when trying to post to a chat in a different account
    post account_chat_messages_path(@account, other_chat), params: {
      message: { content: "Should fail" }
    }
    assert_response :not_found
  end

  test "should require authentication" do
    delete logout_path

    post account_chat_messages_path(@account, @chat), params: {
      message: { content: "Should fail" }
    }
    assert_response :redirect
  end

  test "should require content" do
    assert_no_difference "Message.count" do
      post account_chat_messages_path(@account, @chat), params: {
        message: { content: "" }
      }
      assert_response :unprocessable_entity
    end
  end

end
