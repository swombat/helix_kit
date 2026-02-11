require "test_helper"

class Chats::AgentTriggersControllerTest < ActionDispatch::IntegrationTest

  setup do
    @user = users(:user_1)
    @account = accounts(:personal_account)
    @agent = @account.agents.create!(name: "Test Agent", system_prompt: "You are a test agent")
    @chat = create_group_chat(@account, agent_ids: [ @agent.id ])

    post login_path, params: {
      email_address: @user.email_address,
      password: "password123"
    }
    assert_redirected_to root_path
  end

  test "create triggers specific agent when agent_id provided" do
    post account_chat_agent_trigger_path(@account, @chat),
      params: { agent_id: @agent.to_param },
      as: :json

    assert_response :success
  end

  test "create triggers all agents when no agent_id provided" do
    post account_chat_agent_trigger_path(@account, @chat), as: :json

    assert_response :success
  end

  test "requires authentication" do
    delete logout_path

    post account_chat_agent_trigger_path(@account, @chat), as: :json
    assert_response :redirect
  end

  test "scopes to current account" do
    other_user = User.create!(email_address: "triggerother@example.com")
    other_user.profile.update!(first_name: "Other", last_name: "User")
    other_account = other_user.personal_account
    other_chat = other_account.chats.create!(model_id: "openrouter/auto")

    post account_chat_agent_trigger_path(@account, other_chat), as: :json
    assert_response :not_found
  end

  private

  def create_group_chat(account, agent_ids:)
    chat = account.chats.new(model_id: "openrouter/auto", manual_responses: true)
    chat.agent_ids = agent_ids
    chat.save!
    chat
  end

end
