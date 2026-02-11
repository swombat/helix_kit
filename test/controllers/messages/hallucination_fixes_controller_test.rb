require "test_helper"

class Messages::HallucinationFixesControllerTest < ActionDispatch::IntegrationTest

  setup do
    Setting.instance.update!(allow_chats: true)

    @user = users(:user_1)
    @account = accounts(:personal_account)
    @agent = @account.agents.create!(name: "Test Agent")
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

  test "should fix hallucinated tool calls" do
    # Create a fixable message: assistant role, has agent, has timestamp prefix
    message = @chat.messages.create!(
      role: "assistant",
      content: "[2025-01-15 10:30] Hello, this is the actual response",
      agent: @agent
    )

    assert message.fixable, "Message should be fixable"

    post message_hallucination_fix_path(message)
    assert_redirected_to account_chat_path(@chat.account, @chat)

    # Verify the timestamp was stripped
    message.reload
    assert_equal "Hello, this is the actual response", message.content
  end

  test "site admin can fix hallucinated tool calls on any message" do
    # Create a message in another account
    other_user = User.create!(email_address: "hallfix_other@example.com")
    other_user.profile.update!(first_name: "Other", last_name: "User")
    other_account = other_user.personal_account
    other_agent = other_account.agents.create!(name: "Other Agent")
    other_chat = other_account.chats.create!(model_id: "gpt-4o")
    other_message = other_chat.messages.create!(
      role: "assistant",
      content: "[2025-01-15 10:30] Hallucinated prefix response",
      agent: other_agent
    )

    # Log out and log in as site admin
    delete logout_path
    admin_user = users(:site_admin_user)
    post login_path, params: { email_address: admin_user.email_address, password: "password123" }

    post message_hallucination_fix_path(other_message)
    assert_redirected_to account_chat_path(other_chat.account, other_chat)

    # Verify the timestamp was stripped
    other_message.reload
    assert_equal "Hallucinated prefix response", other_message.content
  end

  test "non-admin cannot fix hallucinated tool calls on other account's message" do
    other_user = User.create!(email_address: "hallfix_other2@example.com")
    other_user.profile.update!(first_name: "Other", last_name: "User")
    other_account = other_user.personal_account
    other_chat = other_account.chats.create!(model_id: "gpt-4o")
    other_message = other_chat.messages.create!(role: "assistant", content: "Hallucinated")

    post message_hallucination_fix_path(other_message)
    assert_response :not_found
  end

  test "requires authentication" do
    message = @chat.messages.create!(role: "assistant", content: "Some content")

    delete logout_path

    post message_hallucination_fix_path(message)
    assert_response :redirect
  end

end
