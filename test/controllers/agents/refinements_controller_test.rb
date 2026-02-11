require "test_helper"

class Agents::RefinementsControllerTest < ActionDispatch::IntegrationTest

  setup do
    @user = users(:user_1)
    @account = accounts(:personal_account)
    @agent = agents(:research_assistant)

    Setting.instance.update!(allow_agents: true)

    post login_path, params: {
      email_address: @user.email_address,
      password: "password123"
    }
    assert_redirected_to root_path
  end

  test "create queues refinement job" do
    assert_enqueued_with(job: MemoryRefinementJob, args: [ @agent.id ]) do
      post account_agent_refinement_path(@account, @agent)
    end

    assert_redirected_to edit_account_agent_path(@account, @agent)
    assert_match(/Refinement session queued/, flash[:notice])
  end

  test "requires authentication" do
    delete logout_path

    post account_agent_refinement_path(@account, @agent)
    assert_response :redirect
  end

  test "scopes to current account" do
    other_agent = agents(:other_account_agent)

    post account_agent_refinement_path(@account, other_agent)
    assert_response :not_found
  end

  test "blocked when agents feature disabled" do
    Setting.instance.update!(allow_agents: false)

    post account_agent_refinement_path(@account, @agent)
    assert_redirected_to root_path
    assert_match(/disabled/, flash[:alert])
  end

end
