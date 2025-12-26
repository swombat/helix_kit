require "test_helper"

class AgentsControllerTest < ActionDispatch::IntegrationTest

  setup do
    @user = users(:user_1)
    @account = accounts(:personal_account)
    @agent = agents(:research_assistant)

    # Enable agents feature
    Setting.instance.update!(allow_agents: true)

    # Sign in user
    post login_path, params: {
      email_address: @user.email_address,
      password: "password123"
    }
    assert_redirected_to root_path
  end

  test "should get index" do
    get account_agents_path(@account)
    assert_response :success
  end

  test "should create agent" do
    assert_difference "Agent.count" do
      post account_agents_path(@account), params: {
        agent: {
          name: "Created Test Agent",
          system_prompt: "You are helpful",
          model_id: "openrouter/auto",
          active: true,
          enabled_tools: []
        }
      }
    end

    agent = Agent.last
    assert_equal "Created Test Agent", agent.name
    assert_equal @account, agent.account
    assert_redirected_to account_agents_path(@account)
  end

  test "should fail to create agent with missing name" do
    assert_no_difference "Agent.count" do
      post account_agents_path(@account), params: {
        agent: {
          name: "",
          system_prompt: "You are helpful",
          model_id: "openrouter/auto"
        }
      }
    end

    assert_redirected_to account_agents_path(@account)
  end

  test "should get edit" do
    get edit_account_agent_path(@account, @agent)
    assert_response :success
  end

  test "should update agent" do
    patch account_agent_path(@account, @agent), params: {
      agent: {
        name: "Updated Name",
        system_prompt: "Updated prompt"
      }
    }

    assert_redirected_to account_agents_path(@account)
    @agent.reload
    assert_equal "Updated Name", @agent.name
    assert_equal "Updated prompt", @agent.system_prompt
  end

  test "should destroy agent" do
    assert_difference "Agent.count", -1 do
      delete account_agent_path(@account, @agent)
    end

    assert_redirected_to account_agents_path(@account)
  end

  test "should scope agents to current account" do
    other_agent = agents(:other_account_agent)

    get edit_account_agent_path(@account, other_agent)
    assert_response :not_found
  end

  test "agents blocked when disabled" do
    Setting.instance.update!(allow_agents: false)

    get account_agents_path(@account)
    assert_redirected_to root_path
    assert_match(/disabled/, flash[:alert])
  end

  test "should require authentication" do
    delete logout_path

    get account_agents_path(@account)
    assert_response :redirect
  end

  test "should update enabled_tools" do
    available_tools = Agent.available_tools.map(&:name)
    skip "No tools available for testing" if available_tools.empty?

    patch account_agent_path(@account, @agent), params: {
      agent: {
        enabled_tools: [ available_tools.first ]
      }
    }

    assert_redirected_to account_agents_path(@account)
    @agent.reload
    assert_includes @agent.enabled_tools, available_tools.first
  end

  test "should fail with duplicate name in same account" do
    existing = @account.agents.create!(name: "Unique Test Agent")

    assert_no_difference "Agent.count" do
      post account_agents_path(@account), params: {
        agent: {
          name: "Unique Test Agent",
          model_id: "openrouter/auto"
        }
      }
    end

    assert_redirected_to account_agents_path(@account)
  end

  test "create should audit" do
    assert_difference "AuditLog.count" do
      post account_agents_path(@account), params: {
        agent: {
          name: "Audited Agent",
          model_id: "openrouter/auto"
        }
      }
    end

    audit = AuditLog.last
    assert_equal "create_agent", audit.action
    assert_equal @user, audit.user
  end

  test "update should audit" do
    assert_difference "AuditLog.count" do
      patch account_agent_path(@account, @agent), params: {
        agent: { name: "Audit Test Name" }
      }
    end

    audit = AuditLog.last
    assert_equal "update_agent", audit.action
    assert_equal @user, audit.user
  end

  test "destroy should audit" do
    assert_difference "AuditLog.count" do
      delete account_agent_path(@account, @agent)
    end

    audit = AuditLog.last
    assert_equal "destroy_agent", audit.action
    assert_equal @user, audit.user
  end

end
