require "test_helper"

class Chats::TranscriptionsControllerTest < ActionDispatch::IntegrationTest

  setup do
    Setting.instance.update!(allow_chats: true)

    @user = users(:user_1)
    @account = accounts(:personal_account)
    @chat = @account.chats.create!(
      model_id: "openrouter/auto",
      title: "Test Conversation"
    )

    sign_in @user
  end

  test "transcribes audio and returns text" do
    audio = fixture_file_upload("test_audio.webm", "audio/webm")

    ElevenLabsStt.stub(:transcribe, "Hello world") do
      post account_chat_transcription_path(@account, @chat),
        params: { audio: audio }

      assert_response :success
      json = JSON.parse(response.body)
      assert_equal "Hello world", json["text"]
    end
  end

  test "returns error when no speech detected" do
    audio = fixture_file_upload("test_audio.webm", "audio/webm")

    ElevenLabsStt.stub(:transcribe, nil) do
      post account_chat_transcription_path(@account, @chat),
        params: { audio: audio }

      assert_response :unprocessable_entity
      json = JSON.parse(response.body)
      assert_equal "No speech detected", json["error"]
    end
  end

  test "returns error when transcription fails" do
    audio = fixture_file_upload("test_audio.webm", "audio/webm")

    mock_transcribe = ->(_audio) { raise ElevenLabsStt::Error, "Rate limit exceeded" }

    ElevenLabsStt.stub(:transcribe, mock_transcribe) do
      post account_chat_transcription_path(@account, @chat),
        params: { audio: audio }

      assert_response :unprocessable_entity
      json = JSON.parse(response.body)
      assert_includes json["error"], "Rate limit"
    end
  end

  test "rejects request without audio parameter" do
    post account_chat_transcription_path(@account, @chat)

    assert_response :bad_request
  end

  test "rejects request for archived chat" do
    @chat.archive!

    audio = fixture_file_upload("test_audio.webm", "audio/webm")

    post account_chat_transcription_path(@account, @chat),
      params: { audio: audio },
      headers: { "Accept" => "application/json" }

    assert_response :unprocessable_entity
    json = JSON.parse(response.body)
    assert_includes json["error"], "archived or deleted"
  end

  test "requires authentication" do
    delete logout_path

    audio = fixture_file_upload("test_audio.webm", "audio/webm")

    post account_chat_transcription_path(@account, @chat),
      params: { audio: audio }

    assert_response :redirect
  end

  test "scopes to current account" do
    other_user = User.create!(email_address: "sttother@example.com")
    other_user.profile.update!(first_name: "Other", last_name: "User")
    other_account = other_user.personal_account
    other_chat = other_account.chats.create!(model_id: "openrouter/auto")

    audio = fixture_file_upload("test_audio.webm", "audio/webm")

    post account_chat_transcription_path(@account, other_chat),
      params: { audio: audio }

    assert_response :not_found
  end

end
