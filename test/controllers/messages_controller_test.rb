require "test_helper"

class MessagesControllerTest < ActionDispatch::IntegrationTest

  setup do
    # Ensure chats feature is enabled
    Setting.instance.update!(allow_chats: true)

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
      post account_chat_messages_path(@account, @chat), params: {
        message: { content: "Hello AI" }
      }
    end

    message = Message.last
    assert_equal "Hello AI", message.content
    assert_equal "user", message.role
    assert_equal @user, message.user
    assert_equal @chat, message.chat

    assert_redirected_to account_chat_path(@account, @chat)
  end

  test "should trigger AI response job when message is created" do
    perform_enqueued_jobs do
      post account_chat_messages_path(@account, @chat), params: {
        message: { content: "Hello AI" }
      }
    end
    # This test verifies that the job runs without error
    # The actual job behavior is tested in the job tests
  end

  test "should handle single file attachment" do
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
    assert_equal "test_image.png", message.files.first.filename.to_s
    assert_equal "image/png", message.files.first.content_type
    assert_redirected_to account_chat_path(@account, @chat)
  end

  test "should handle multiple file attachments" do
    image_file = fixture_file_upload("test_image.png", "image/png")
    pdf_file = fixture_file_upload("test_document.pdf", "application/pdf")
    audio_file = fixture_file_upload("test_audio.mp3", "audio/mpeg")

    assert_difference "Message.count" do
      post account_chat_messages_path(@account, @chat), params: {
        message: { content: "Multiple files attached" },
        files: [ image_file, pdf_file, audio_file ]
      }
    end

    message = Message.last
    assert message.files.attached?
    assert_equal 3, message.files.count

    filenames = message.files.map { |f| f.filename.to_s }
    assert_includes filenames, "test_image.png"
    assert_includes filenames, "test_document.pdf"
    assert_includes filenames, "test_audio.mp3"
    assert_redirected_to account_chat_path(@account, @chat)
  end

  test "should create message without files (backwards compatibility)" do
    assert_difference "Message.count" do
      post account_chat_messages_path(@account, @chat), params: {
        message: { content: "Message without files" }
      }
    end

    message = Message.last
    assert_not message.files.attached?
    assert_equal 0, message.files.count
    assert_equal "Message without files", message.content
    assert_redirected_to account_chat_path(@account, @chat)
  end

  test "should reject invalid file types" do
    invalid_file = fixture_file_upload("test.exe", "application/x-msdownload")

    assert_no_difference "Message.count" do
      post account_chat_messages_path(@account, @chat), params: {
        message: { content: "Invalid file type" },
        files: [ invalid_file ]
      }
    end

    assert_response :redirect
    follow_redirect!
    assert_match /file type not supported/, flash[:alert]
  end

  test "should handle mixed valid and invalid files" do
    valid_file = fixture_file_upload("test_image.png", "image/png")
    invalid_file = fixture_file_upload("test.exe", "application/x-msdownload")

    assert_no_difference "Message.count" do
      post account_chat_messages_path(@account, @chat), params: {
        message: { content: "Mixed file types" },
        files: [ valid_file, invalid_file ]
      }
    end

    assert_response :redirect
    follow_redirect!
    assert_match /file type not supported/, flash[:alert]
  end

  test "should provide file metadata in JSON serialization" do
    file = fixture_file_upload("test_image.png", "image/png")

    assert_difference "Message.count" do
      post account_chat_messages_path(@account, @chat), params: {
        message: { content: "File metadata test" },
        files: [ file ]
      }
    end

    message = Message.last

    # Test basic file attachment properties
    assert message.files.attached?
    assert_equal 1, message.files.count
    attached_file = message.files.first
    assert_equal "test_image.png", attached_file.filename.to_s
    assert_equal "image/png", attached_file.content_type
    assert attached_file.byte_size > 0
  end

  test "should provide file paths for LLM integration" do
    file = fixture_file_upload("test_image.png", "image/png")

    assert_difference "Message.count" do
      post account_chat_messages_path(@account, @chat), params: {
        message: { content: "File paths test" },
        files: [ file ]
      }
    end

    message = Message.last
    file_paths = message.file_paths_for_llm

    assert_equal 1, file_paths.length
    assert file_paths.first.is_a?(String)
    assert file_paths.first.length > 0
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
      # Validation errors redirect back to the chat with an error message
      assert_response :redirect
    end
  end

  test "should require content for JSON requests" do
    assert_no_difference "Message.count" do
      post account_chat_messages_path(@account, @chat), params: {
        message: { content: "" }
      }, as: :json
      assert_response :unprocessable_entity
      assert_includes response.parsed_body["errors"], "Content can't be blank"
    end
  end

  test "should handle Inertia requests properly" do
    assert_difference "Message.count", 1 do
      post account_chat_messages_path(@account, @chat), params: {
        message: { content: "Hello from Inertia" }
      }, headers: {
        "X-Inertia" => "true",
        "X-Inertia-Version" => "1.0"
      }
      assert_response :redirect
      assert_redirected_to account_chat_path(@account, @chat)
    end

    assert_equal "Hello from Inertia", Message.last.content
    assert_equal @user, Message.last.user
    assert_equal "user", Message.last.role
  end

  test "should handle first message in a new chat" do
    # Create a new empty chat
    new_chat = @account.chats.create!(
      model_id: "openrouter/auto",
      title: "New Empty Chat"
    )
    assert_equal 0, new_chat.messages.count

    # Send the first message
    assert_difference "Message.count" do
      post account_chat_messages_path(@account, new_chat), params: {
        message: { content: "First message in new chat" }
      }
    end

    message = Message.last
    assert_equal "First message in new chat", message.content
    assert_equal "user", message.role
    assert_equal @user, message.user
    assert_equal new_chat, message.chat

    assert_redirected_to account_chat_path(@account, new_chat)
  end

  test "should retry failed message" do
    # Create a failed assistant message
    user_message = @chat.messages.create!(
      user: @user,
      role: "user",
      content: "Original question"
    )
    failed_message = @chat.messages.create!(
      role: "assistant",
      content: "Partial response"
    )

    # Test that the retry endpoint works
    post retry_message_path(failed_message)
    assert_response :success

    # Verify that the AiResponseJob gets enqueued
    assert_enqueued_jobs 1, only: AiResponseJob
  end

  test "retry should scope to current account" do
    # Create message in different account
    other_user = User.create!(
      email_address: "retryother@example.com"
    )
    other_user.profile.update!(first_name: "Other", last_name: "User")
    other_account = other_user.personal_account
    other_chat = other_account.chats.create!(model_id: "gpt-4o")
    other_message = other_chat.messages.create!(
      role: "assistant",
      content: "Failed"
    )

    # Should return 404 when trying to retry message from different account
    post retry_message_path(other_message)
    assert_response :not_found
  end

  test "retry requires authentication" do
    message = @chat.messages.create!(
      role: "assistant",
      content: "Some content"
    )

    delete logout_path

    post retry_message_path(message)
    assert_response :redirect
  end

  test "should touch chat when message is created" do
    original_updated_at = @chat.updated_at

    # Wait a moment to ensure different timestamp
    sleep 0.1

    post account_chat_messages_path(@account, @chat), params: {
      message: { content: "Touch test" }
    }

    @chat.reload
    assert @chat.updated_at > original_updated_at
  end

end
