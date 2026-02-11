require "test_helper"

class Accounts::AgentInitiationsControllerTest < ActionDispatch::IntegrationTest

  setup do
    @user = users(:user_1)
    @account = accounts(:personal_account)

    Setting.instance.update!(allow_agents: true)

    post login_path, params: {
      email_address: @user.email_address,
      password: "password123"
    }
    assert_redirected_to root_path
  end

  test "create triggers initiation for all active agents" do
    assert_enqueued_jobs @account.agents.active.count, only: AgentInitiationDecisionJob do
      post account_agent_initiation_path(@account)
    end

    assert_redirected_to account_agents_path(@account)
    assert_match(/Initiation triggered/, flash[:notice])
  end

  test "requires authentication" do
    delete logout_path

    post account_agent_initiation_path(@account)
    assert_response :redirect
  end

  test "blocked when agents feature disabled" do
    Setting.instance.update!(allow_agents: false)

    post account_agent_initiation_path(@account)
    assert_redirected_to root_path
    assert_match(/disabled/, flash[:alert])
  end

end
