require "test_helper"
require "webmock/minitest"

class Agents::PromoteControllerTest < ActionDispatch::IntegrationTest

  setup do
    @user = users(:user_1)
    @account = accounts(:personal_account)
    @agent = agents(:research_assistant)

    sign_in @user
  end

  test "github access validates and stores account token" do
    AgentRepoCreator.stub(:validate_token!, "octocat") do
      post github_access_promote_account_agent_path(@account, @agent), params: { github_pat: "ghp_test" }
    end

    assert_redirected_to promote_account_agent_path(@account, @agent)
    @account.reload
    assert_equal "octocat", @account.github_login
    assert_equal "ghp_test", @account.github_pat
  end

  test "begin creates scoped credentials and marks agent migrating" do
    @account.update!(github_pat: "ghp_test", github_login: "octocat")
    repo = AgentRepoCreator::Result.new(
      owner: "octocat",
      name: "research-assistant-agent",
      html_url: "https://github.com/octocat/research-assistant-agent",
      ssh_url: "git@github.com:octocat/research-assistant-agent.git",
      clone_url: "https://github.com/octocat/research-assistant-agent.git",
      default_branch: "main"
    )
    deploy_key = AgentRepoCreator::DeployKey.new(id: "123", private_key: "PRIVATE KEY", public_key: "PUBLIC KEY")
    repo_creator = FakeRepoCreator.new(repo, deploy_key)

    assert_difference "ApiKey.count", 1 do
      AgentRepoCreator.stub(:new, repo_creator) do
        post begin_promote_account_agent_path(@account, @agent),
          params: { repo_name: "research-assistant-agent" },
          headers: { "X-Inertia" => true }
      end
    end

    assert_response :success
    @agent.reload

    assert_equal "migrating", @agent.runtime
    assert_predicate @agent.uuid, :present?
    assert_predicate @agent.trigger_bearer_token, :present?
    assert_not_nil @agent.migration_started_at
    assert_equal @agent, @agent.outbound_api_key.agent
    assert_equal "https://github.com/octocat/research-assistant-agent", @agent.github_repo_url
    assert_equal "octocat", @agent.github_repo_owner
    assert_equal "research-assistant-agent", @agent.github_repo_name
    assert_equal "123", @agent.github_deploy_key_id
    assert_equal "PRIVATE KEY", @agent.github_deploy_key_priv
    assert repo_creator.committed?

    props = JSON.parse(response.body)["props"]
    generated = props.fetch("generated_credentials")
    assert_predicate generated.fetch("master_key"), :present?
    assert_includes generated.fetch("credentials_yml_enc"), "algorithm: aes-256-gcm"
    assert_equal "git@github.com:octocat/research-assistant-agent.git", generated.dig("repo", "ssh_url")
  end

  test "begin refuses an already migrating agent" do
    key = ApiKey.generate_for(@user, name: "existing", agent: @agent)
    @agent.update!(
      runtime: "migrating",
      uuid: SecureRandom.uuid_v7,
      trigger_bearer_token: "tr_existing",
      outbound_api_key: key,
      migration_started_at: Time.current
    )

    assert_no_difference "ApiKey.count" do
      post begin_promote_account_agent_path(@account, @agent)
    end

    assert_redirected_to promote_account_agent_path(@account, @agent)
  end

  test "begin requires github access" do
    assert_no_difference "ApiKey.count" do
      post begin_promote_account_agent_path(@account, @agent)
    end

    assert_redirected_to promote_account_agent_path(@account, @agent)
  end

  test "regenerate credentials recovers master key for prepared migrating repo" do
    @account.update!(github_pat: "ghp_test", github_login: "octocat")
    old_key = ApiKey.generate_for(@user, name: "old agent key", agent: @agent)
    @agent.update!(
      runtime: "migrating",
      uuid: SecureRandom.uuid_v7,
      trigger_bearer_token: "tr_existing",
      outbound_api_key: old_key,
      github_repo_url: "https://github.com/octocat/research-assistant-agent",
      github_repo_owner: "octocat",
      github_repo_name: "research-assistant-agent",
      github_deploy_key_priv: "PRIVATE KEY"
    )
    repo = AgentRepoCreator::Result.new(
      owner: "octocat",
      name: "research-assistant-agent",
      html_url: "https://github.com/octocat/research-assistant-agent",
      ssh_url: "git@github.com:octocat/research-assistant-agent.git",
      clone_url: "https://github.com/octocat/research-assistant-agent.git",
      default_branch: "main"
    )
    repo_creator = FakeRepoCreator.new(repo, nil)

    assert_no_difference "ApiKey.count" do
      AgentRepoCreator.stub(:new, repo_creator) do
        post regenerate_credentials_promote_account_agent_path(@account, @agent),
          headers: { "X-Inertia" => true }
      end
    end

    assert_response :success
    assert repo_creator.committed?
    assert_not ApiKey.exists?(old_key.id)
    props = JSON.parse(response.body)["props"]
    generated = props.fetch("generated_credentials")
    assert_predicate generated.fetch("master_key"), :present?
    assert_equal true, generated.fetch("regenerated")
    assert_equal "git@github.com:octocat/research-assistant-agent.git", generated.dig("repo", "ssh_url")
  end

  test "cancel returns agent to inline and revokes scoped key" do
    key = ApiKey.generate_for(@user, name: "agent key", agent: @agent)
    @agent.update!(
      runtime: "migrating",
      uuid: SecureRandom.uuid_v7,
      trigger_bearer_token: "tr_existing",
      outbound_api_key: key,
      migration_started_at: Time.current
    )

    assert_difference "ApiKey.count", -1 do
      post cancel_promote_account_agent_path(@account, @agent)
    end

    @agent.reload
    assert_equal "inline", @agent.runtime
    assert_nil @agent.trigger_bearer_token
    assert_nil @agent.outbound_api_key
    assert_nil @agent.migration_started_at
  end

  test "send test request probes external runtime synchronously" do
    @agent.update!(
      runtime: "external",
      uuid: SecureRandom.uuid_v7,
      endpoint_url: "https://agent.example.com",
      trigger_bearer_token: "tr_valid",
      health_state: "healthy",
      consecutive_health_failures: 0
    )
    trigger = stub_request(:post, "https://agent.example.com/trigger")
      .with(headers: { "Authorization" => "Bearer tr_valid" })
      .to_return(status: 200, body: { status: "accepted" }.to_json)

    post send_test_request_account_agent_path(@account, @agent)

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal "runtime_reachable", json["status"]
    assert_predicate json["conversation_id"], :present?
    assert_requested trigger
  end

  class FakeRepoCreator

    def initialize(repo, deploy_key)
      @repo = repo
      @deploy_key = deploy_key
      @committed = false
    end

    def create_repo!
      @repo
    end

    def create_deploy_key!(_repo)
      @deploy_key
    end

    def fetch_repo!(owner:, name:)
      @repo
    end

    def deploy_yml(_repo)
      "agent_id: research-assistant\n"
    end

    def commit_runtime_files!(_repo, identity_files:, credentials_yml_enc:, deploy_yml:)
      @committed = identity_files.present? && credentials_yml_enc.present? && deploy_yml.present?
    end

    def committed?
      @committed
    end

  end

end
