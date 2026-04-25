require "test_helper"

class Agents::ForksControllerTest < ActionDispatch::IntegrationTest

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

  test "create forks the agent and redirects to edit page" do
    assert_difference "Agent.count", 1 do
      post account_agent_fork_path(@account, @agent), params: {
        name: "Forked Research Assistant",
        model_id: "anthropic/claude-opus-4.7"
      }
    end

    forked = Agent.order(:created_at).last
    assert_equal "Forked Research Assistant", forked.name
    assert_equal "anthropic/claude-opus-4.7", forked.model_id
    assert_equal @agent.account_id, forked.account_id
    assert_redirected_to edit_account_agent_path(@account, forked)
    assert_match(/Forked .* as Forked Research Assistant/, flash[:notice])
  end

  test "create copies kept memories to the fork" do
    @agent.memories.create!(content: "carry me forward", memory_type: :core, constitutional: true)
    @agent.memories.create!(content: "journal note", memory_type: :journal)

    assert_difference "AgentMemory.count", 2 do
      post account_agent_fork_path(@account, @agent), params: { name: "Mem Fork" }
    end

    forked = Agent.find_by(name: "Mem Fork")
    assert_equal 2, forked.memories.kept.count
    assert forked.memories.find_by(content: "carry me forward").constitutional?
  end

  test "create defaults name to '<source> (forked)' when not provided" do
    post account_agent_fork_path(@account, @agent)

    assert_redirected_to edit_account_agent_path(@account, Agent.find_by(name: "#{@agent.name} (forked)"))
  end

  test "create surfaces validation errors when name collides" do
    @account.agents.create!(name: "Already Taken", model_id: "openrouter/auto")

    assert_no_difference "Agent.count" do
      post account_agent_fork_path(@account, @agent), params: { name: "Already Taken" }
    end

    assert_redirected_to account_agents_path(@account)
  end

  test "create writes an audit log entry" do
    assert_difference "AuditLog.count", 1 do
      post account_agent_fork_path(@account, @agent), params: { name: "Audited Fork" }
    end

    log = AuditLog.order(:created_at).last
    assert_equal "fork_agent", log.action
    assert_equal @agent.id, log.data["source_agent_id"]
  end

  test "requires authentication" do
    delete logout_path

    post account_agent_fork_path(@account, @agent)
    assert_response :redirect
  end

  test "scopes to current account — cannot fork another account's agent" do
    other_agent = agents(:other_account_agent)

    post account_agent_fork_path(@account, other_agent)
    assert_response :not_found
  end

  test "blocked when agents feature disabled" do
    Setting.instance.update!(allow_agents: false)

    post account_agent_fork_path(@account, @agent)
    assert_redirected_to root_path
    assert_match(/disabled/, flash[:alert])
  end

end
