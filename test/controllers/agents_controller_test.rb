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

  # Memory tests

  test "destroy_memory deletes a memory and redirects" do
    memory = @agent.memories.create!(content: "Test memory", memory_type: :journal)

    assert_difference "@agent.memories.count", -1 do
      delete destroy_memory_account_agent_path(@account, @agent, memory_id: memory.id)
    end

    assert_redirected_to edit_account_agent_path(@account, @agent)
    assert_match(/deleted/, flash[:notice])
  end

  test "create_memory creates a core memory and redirects" do
    assert_difference "@agent.memories.count", 1 do
      post create_memory_account_agent_path(@account, @agent), params: {
        memory: { content: "Test core memory", memory_type: "core" }
      }
    end

    assert_redirected_to edit_account_agent_path(@account, @agent)
    assert_match(/created/, flash[:notice])

    memory = @agent.memories.last
    assert_equal "Test core memory", memory.content
    assert_equal "core", memory.memory_type
  end

  test "create_memory creates a journal memory" do
    assert_difference "@agent.memories.count", 1 do
      post create_memory_account_agent_path(@account, @agent), params: {
        memory: { content: "Test journal entry", memory_type: "journal" }
      }
    end

    memory = @agent.memories.last
    assert_equal "journal", memory.memory_type
  end

  test "create_memory fails with blank content" do
    assert_no_difference "@agent.memories.count" do
      post create_memory_account_agent_path(@account, @agent), params: {
        memory: { content: "", memory_type: "core" }
      }
    end

    assert_redirected_to edit_account_agent_path(@account, @agent)
  end

  # Send test telegram tests

  test "send_test_telegram redirects with error when telegram not configured" do
    post send_test_telegram_account_agent_path(@account, @agent)

    assert_redirected_to edit_account_agent_path(@account, @agent)
    assert_match(/not configured/, flash[:alert])
  end

  test "send_test_telegram redirects with error when no subscribers" do
    @agent.update!(telegram_bot_token: "123:ABC", telegram_bot_username: "test_bot")

    post send_test_telegram_account_agent_path(@account, @agent)

    assert_redirected_to edit_account_agent_path(@account, @agent)
    assert_match(/No users have connected/, flash[:alert])
  end

  test "send_test_telegram sends to subscribers and redirects with success" do
    @agent.update!(telegram_bot_token: "123:ABC", telegram_bot_username: "test_bot")
    @agent.telegram_subscriptions.create!(user: @user, telegram_chat_id: 12345)

    # Stub Net::HTTP.post to return a successful Telegram response
    fake_response = Struct.new(:body).new({ "ok" => true, "result" => {} }.to_json)
    Net::HTTP.stub(:post, fake_response) do
      post send_test_telegram_account_agent_path(@account, @agent)
    end

    assert_redirected_to edit_account_agent_path(@account, @agent)
    assert_match(/Test notification sent to 1 subscriber/, flash[:notice])
  end

  test "send_test_telegram handles telegram API error" do
    @agent.update!(telegram_bot_token: "123:ABC", telegram_bot_username: "test_bot")
    @agent.telegram_subscriptions.create!(user: @user, telegram_chat_id: 12345)

    fake_response = Struct.new(:body).new({ "ok" => false, "description" => "Bot was blocked" }.to_json)
    Net::HTTP.stub(:post, fake_response) do
      post send_test_telegram_account_agent_path(@account, @agent)
    end

    assert_redirected_to edit_account_agent_path(@account, @agent)
    assert_match(/Telegram error/, flash[:alert])
  end

  # Register telegram webhook tests

  test "register_telegram_webhook redirects with error when telegram not configured" do
    post register_telegram_webhook_account_agent_path(@account, @agent)

    assert_redirected_to edit_account_agent_path(@account, @agent)
    assert_match(/not configured/, flash[:alert])
  end

  test "register_telegram_webhook registers and redirects with success" do
    @agent.update!(telegram_bot_token: "123:ABC", telegram_bot_username: "test_bot")

    fake_set_response = Struct.new(:body).new({ "ok" => true }.to_json)
    fake_info_response = Struct.new(:body).new({ "ok" => true, "result" => { "url" => "https://example.com/webhook" } }.to_json)

    call_count = 0
    fake_post = lambda do |_uri, _body, _headers|
      call_count += 1
      call_count == 1 ? fake_set_response : fake_info_response
    end

    Net::HTTP.stub(:post, fake_post) do
      post register_telegram_webhook_account_agent_path(@account, @agent)
    end

    assert_redirected_to edit_account_agent_path(@account, @agent)
    assert_match(/Webhook registered/, flash[:notice])
  end

end
