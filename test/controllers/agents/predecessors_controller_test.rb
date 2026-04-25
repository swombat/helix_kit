require "test_helper"

class Agents::PredecessorsControllerTest < ActionDispatch::IntegrationTest

  setup do
    @user = users(:user_1)
    @account = accounts(:personal_account)
    @agent = agents(:research_assistant)
    @agent.update!(model_id: "anthropic/claude-opus-4.6")

    Setting.instance.update!(allow_agents: true)

    post login_path, params: {
      email_address: @user.email_address,
      password: "password123"
    }
    assert_redirected_to root_path
  end

  test "create upgrades successor's model_id and creates a predecessor" do
    assert_difference "Agent.count", 1 do
      post account_agent_predecessor_path(@account, @agent), params: {
        to_model: "anthropic/claude-opus-4.7",
        predecessor_name: "Research Assistant (Opus 4.6)"
      }
    end

    @agent.reload
    assert_equal "anthropic/claude-opus-4.7", @agent.model_id

    predecessor = Agent.find_by(name: "Research Assistant (Opus 4.6)")
    assert_equal "anthropic/claude-opus-4.6", predecessor.model_id
    assert_equal @agent.account_id, predecessor.account_id

    assert_redirected_to edit_account_agent_path(@account, @agent)
    assert_match(/Upgraded Research Assistant to Claude Opus 4\.7/, flash[:notice])
    assert_match(/preserved past-self as Research Assistant \(Opus 4\.6\)/, flash[:notice])
  end

  test "create copies kept memories to the predecessor only" do
    @agent.memories.create!(content: "carry me forward", memory_type: :core, constitutional: true)
    @agent.memories.create!(content: "journal note", memory_type: :journal)

    assert_difference "AgentMemory.count", 2 do
      post account_agent_predecessor_path(@account, @agent), params: {
        to_model: "anthropic/claude-opus-4.7"
      }
    end

    predecessor = Agent.where.not(id: @agent.id).order(:created_at).last
    assert_equal 2, predecessor.memories.kept.count
    assert predecessor.memories.find_by(content: "carry me forward").constitutional?

    # Successor still has its own memories too
    @agent.reload
    assert_equal 2, @agent.memories.kept.count
  end

  test "create defaults predecessor name to '<successor> (<old model label>)'" do
    post account_agent_predecessor_path(@account, @agent), params: {
      to_model: "anthropic/claude-opus-4.7"
    }

    assert_not_nil Agent.find_by(name: "Research Assistant (Claude Opus 4.6)")
  end

  test "create surfaces validation errors when predecessor name collides" do
    @account.agents.create!(name: "Already Taken", model_id: "openrouter/auto")

    assert_no_difference "Agent.count" do
      post account_agent_predecessor_path(@account, @agent), params: {
        to_model: "anthropic/claude-opus-4.7",
        predecessor_name: "Already Taken"
      }
    end

    assert_redirected_to account_agents_path(@account)

    # Successor must NOT have been upgraded — transaction rolled back
    @agent.reload
    assert_equal "anthropic/claude-opus-4.6", @agent.model_id
  end

  test "create rejects blank to_model" do
    assert_no_difference "Agent.count" do
      post account_agent_predecessor_path(@account, @agent), params: { to_model: "" }
    end

    assert_redirected_to account_agents_path(@account)
    assert_match(/to_model is required/, flash[:alert])

    @agent.reload
    assert_equal "anthropic/claude-opus-4.6", @agent.model_id
  end

  test "create writes an audit log entry naming both models" do
    assert_difference "AuditLog.count", 1 do
      post account_agent_predecessor_path(@account, @agent), params: {
        to_model: "anthropic/claude-opus-4.7",
        predecessor_name: "Audited Predecessor"
      }
    end

    log = AuditLog.order(:created_at).last
    assert_equal "create_predecessor", log.action
    assert_equal @agent.id, log.data["successor_agent_id"]
    assert_equal "anthropic/claude-opus-4.6", log.data["from_model"]
    assert_equal "anthropic/claude-opus-4.7", log.data["to_model"]
  end

  test "requires authentication" do
    delete logout_path

    post account_agent_predecessor_path(@account, @agent), params: {
      to_model: "anthropic/claude-opus-4.7"
    }
    assert_response :redirect
  end

  test "scopes to current account — cannot upgrade another account's agent" do
    other_agent = agents(:other_account_agent)

    post account_agent_predecessor_path(@account, other_agent), params: {
      to_model: "anthropic/claude-opus-4.7"
    }
    assert_response :not_found
  end

  test "blocked when agents feature disabled" do
    Setting.instance.update!(allow_agents: false)

    post account_agent_predecessor_path(@account, @agent), params: {
      to_model: "anthropic/claude-opus-4.7"
    }
    assert_redirected_to root_path
    assert_match(/disabled/, flash[:alert])
  end

end
