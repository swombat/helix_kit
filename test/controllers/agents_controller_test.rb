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

  test "index creation link redirects to the creation wizard" do
    get account_agents_path(@account, create: true)

    assert_redirected_to new_account_agent_path(@account)
  end

  test "should get new agent wizard" do
    get new_account_agent_path(@account)

    assert_response :success
    assert_equal @account.to_param, inertia_shared_props.dig("account", "id")
  end

  test "should create born-hosted agent" do
    assert_difference [ "Agent.count", "ApiKey.count" ], 1 do
      assert_enqueued_with(job: PromoteAgentJob) do
        post account_agents_path(@account), params: {
          agent: {
            name: "Created Test Agent",
            system_prompt: "You are helpful",
            model_id: "openrouter/auto",
            scheduled_wakes_enabled: true
          }
        }
      end
    end

    agent = Agent.last
    assert_equal "Created Test Agent", agent.name
    assert_equal @account, agent.account
    assert_equal "provisioning", agent.runtime
    assert_predicate agent.birth_committed_at, :present?
    assert_predicate agent.provisioning_started_at, :present?
    assert_predicate agent.trigger_bearer_token, :present?
    assert_equal agent, agent.outbound_api_key.agent
    assert_redirected_to onboarding_account_agent_path(@account, agent)
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

    assert_redirected_to new_account_agent_path(@account)
  end

  test "blank soul seed requires an explicit open beginning" do
    assert_no_difference [ "Agent.count", "ApiKey.count" ] do
      post account_agents_path(@account), params: {
        agent: {
          name: "Unconfirmed Blank Agent",
          system_prompt: "",
          model_id: "openrouter/auto"
        }
      }
    end

    assert_redirected_to new_account_agent_path(@account)
  end

  test "explicit open beginning creates a born-hosted agent" do
    assert_difference [ "Agent.count", "ApiKey.count" ], 1 do
      post account_agents_path(@account), params: {
        agent: {
          name: "Open Beginning Agent",
          system_prompt: "",
          model_id: "openrouter/auto",
          open_beginning: true
        }
      }
    end

    agent = Agent.last
    assert_predicate agent, :born_hosted?
    assert_equal "", agent.system_prompt
    assert_redirected_to onboarding_account_agent_path(@account, agent)
  end

  test "should get edit" do
    get edit_account_agent_path(@account, @agent)
    assert_response :success
  end

  test "edit includes paginated interaction costs with chat context" do
    chat = @account.chats.create!(model_id: "openrouter/auto", title: "Dad cost investigation")
    AgentRuntimeInteraction.create!(
      agent: @agent,
      chat: chat,
      trigger_kind: "conversation",
      requested_by: "HelixKit conversation",
      started_at: Time.current,
      telemetry_schema_version: 1,
      chaos_telemetry_status: "detailed",
      usage_scope: "invocation",
      usage_complete: true,
      provider: "anthropic",
      model: "claude-fable-5",
      session_outcome: "resumed",
      prompt_mode: "delta",
      uncached_input_tokens: 100,
      cache_creation_input_tokens: 20,
      cache_read_input_tokens: 500,
      output_tokens: 30
    )

    get edit_account_agent_path(@account, @agent), params: { tab: "interactions" }

    interaction = inertia_shared_props.fetch("interactions").first
    assert_equal "Dad cost investigation", interaction["chat_title"]
    assert_equal "Conversation · Resumed · delta prompt", interaction["summary"]
    assert_equal 500, interaction.dig("tokens", "cache_read_input_tokens")
    assert_equal 1, inertia_shared_props.dig("interactions_pagination", "count")
  end

  test "interaction costs are reverse chronological and paginated" do
    26.times do |index|
      AgentRuntimeInteraction.create!(
        agent: @agent,
        trigger_kind: "wake",
        requested_by: "Wake #{index}",
        started_at: index.minutes.ago,
        created_at: index.minutes.ago
      )
    end

    get edit_account_agent_path(@account, @agent), params: { tab: "interactions" }

    first_page = inertia_shared_props.fetch("interactions")
    assert_equal 25, first_page.size
    assert_equal "Wake 0", first_page.first["requested_by"]
    assert_equal 2, inertia_shared_props.dig("interactions_pagination", "pages")

    get edit_account_agent_path(@account, @agent), params: { tab: "interactions", page: 2 }
    @inertia_props = nil

    second_page = inertia_shared_props.fetch("interactions")
    assert_equal 1, second_page.size
    assert_equal "Wake 25", second_page.first["requested_by"]
  end

  test "edit includes interaction costs grouped by day" do
    AgentRuntimeInteraction.create!(
      agent: @agent,
      trigger_kind: "wake",
      started_at: Time.zone.local(2026, 7, 22, 12),
      telemetry_schema_version: 1,
      usage_scope: "trigger",
      usage_complete: true,
      provider: "anthropic",
      model: "claude-sonnet-5",
      uncached_input_tokens: 1_000,
      cache_creation_input_tokens: 0,
      cache_read_input_tokens: 0,
      output_tokens: 25
    )

    get edit_account_agent_path(@account, @agent), params: { tab: "costs" }

    report = inertia_shared_props.fetch("cost_report")
    assert_equal "0.00225", report["total_amount_usd"]
    assert_equal "2026-07-22", report.dig("days", 0, "date")
  end

  test "edit does not load docker filesystem diagnostics inline" do
    Agents::FilesystemDump.stub(:new, ->(*) { raise "filesystem dump should be loaded asynchronously" }) do
      Agents::Sandbox.stub(:new, ->(*) { raise "sandbox status should be loaded asynchronously" }) do
        get edit_account_agent_path(@account, @agent)
      end
    end

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

  test "born-hosted soul seed is write-once while display metadata remains editable" do
    @agent.update!(system_prompt: "The committed beginning")
    @agent.update!(
      birth_committed_at: Time.current,
      runtime: "provisioning"
    )

    patch account_agent_path(@account, @agent), params: {
      agent: {
        name: "New display label",
        system_prompt: "A replacement beginning",
        colour: "emerald"
      }
    }

    assert_redirected_to account_agents_path(@account)
    @agent.reload
    assert_equal "New display label", @agent.name
    assert_equal "The committed beginning", @agent.system_prompt
    assert_equal "emerald", @agent.colour
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

  test "external agent update allows display name and model changes but ignores self-managed identity params" do
    @agent.update!(
      name: "Hosted Researcher",
      model_id: "openrouter/auto",
      voice_id: "original-voice"
    )
    @agent.update!(runtime: "external", uuid: SecureRandom.uuid_v7)

    patch account_agent_path(@account, @agent), params: {
      agent: {
        name: "Browser Rename",
        system_prompt: "Changed prompt",
        model_id: "openai/gpt-5.2",
        voice_id: "changed-voice",
        paused: true,
        colour: "emerald"
      }
    }

    assert_redirected_to account_agents_path(@account)
    @agent.reload
    assert_equal "Browser Rename", @agent.name
    assert_not_equal "Changed prompt", @agent.system_prompt
    assert_equal "openai/gpt-5.2", @agent.model_id
    assert_equal "changed-voice", @agent.voice_id
    assert_equal "emerald", @agent.colour
    assert @agent.paused?
  end

  test "external agent can enable persistent sessions" do
    @agent.update!(runtime: "external", uuid: SecureRandom.uuid_v7)

    patch account_agent_path(@account, @agent), params: {
      agent: { persistent_session: true }
    }

    assert_redirected_to account_agents_path(@account)
    assert @agent.reload.persistent_session?
  end

  test "external agent can enable a persistent wake session" do
    @agent.update!(runtime: "external", uuid: SecureRandom.uuid_v7)

    patch account_agent_path(@account, @agent), params: {
      agent: { persistent_wake_session: true }
    }

    assert_redirected_to account_agents_path(@account)
    assert @agent.reload.persistent_wake_session?
  end

  test "external agent can disable scheduled wakes" do
    @agent.update!(runtime: "external", uuid: SecureRandom.uuid_v7)

    patch account_agent_path(@account, @agent), params: {
      agent: { scheduled_wakes_enabled: false }
    }

    assert_redirected_to account_agents_path(@account)
    assert_not @agent.reload.scheduled_wakes_enabled?
  end

  test "HelixKit-hosted agent can disable scheduled wakes" do
    assert @agent.inline?

    patch account_agent_path(@account, @agent), params: {
      agent: { scheduled_wakes_enabled: false }
    }

    assert_redirected_to account_agents_path(@account)
    assert_not @agent.reload.scheduled_wakes_enabled?
  end

  test "external agent can set heartbeat wakes per day" do
    @agent.update!(runtime: "external", uuid: SecureRandom.uuid_v7)

    patch account_agent_path(@account, @agent), params: {
      agent: { heartbeat_wakes_per_day: 1 }
    }

    assert_redirected_to account_agents_path(@account)
    assert_equal 1, @agent.reload.heartbeat_wakes_per_day
  end

  test "HelixKit-hosted agent can set heartbeat wakes per day" do
    patch account_agent_path(@account, @agent), params: {
      agent: { heartbeat_wakes_per_day: 2 }
    }

    assert_redirected_to account_agents_path(@account)
    assert_equal 2, @agent.reload.heartbeat_wakes_per_day
  end

  test "should fail with duplicate name in same account" do
    existing = @account.agents.create!(name: "Unique Test Agent")

    assert_no_difference "Agent.count" do
      post account_agents_path(@account), params: {
          agent: {
            name: "Unique Test Agent",
            model_id: "openrouter/auto",
            open_beginning: true
        }
      }
    end

    assert_redirected_to new_account_agent_path(@account)
  end

  test "create should audit" do
    assert_difference "AuditLog.count" do
      post account_agents_path(@account), params: {
          agent: {
            name: "Audited Agent",
            model_id: "openrouter/auto",
            open_beginning: true
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

  test "member can edit team agent" do
    sign_in users(:existing_user)

    get edit_account_agent_path(accounts(:team_account), agents(:other_account_agent))

    assert_response :success
  end

end
