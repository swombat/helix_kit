require "test_helper"
require "webmock/minitest"

class AgentRepoCreatorTest < ActiveSupport::TestCase

  setup do
    @account = accounts(:personal_account)
    @agent = agents(:research_assistant)
    @account.update!(github_pat: "ghp_test", github_login: "octocat")
  end

  test "validates github token and returns login" do
    request = stub_request(:get, "https://api.github.com/user")
      .with(headers: { "Authorization" => "Bearer ghp_test" })
      .to_return(status: 200, body: { login: "octocat" }.to_json)

    assert_equal "octocat", AgentRepoCreator.validate_token!("ghp_test")
    assert_requested request
  end

  test "creates a repo from the runtime template" do
    request = stub_request(:post, "https://api.github.com/repos/swombat/helix-kit-agents/generate")
      .with(body: hash_including(owner: "octocat", name: "research-agent", private: true))
      .to_return(status: 201, body: repo_response.to_json)

    repo = creator.create_repo!

    assert_equal "octocat", repo.owner
    assert_equal "research-agent", repo.name
    assert_equal "git@github.com:octocat/research-agent.git", repo.ssh_url
    assert_requested request
  end

  test "creates a read-write deploy key" do
    repo = repo_result
    request = stub_request(:post, "https://api.github.com/repos/octocat/research-agent/keys")
      .with(body: hash_including(key: "PUBLIC KEY", read_only: false))
      .to_return(status: 201, body: { id: 12345 }.to_json)

    deploy_key = creator.stub(:generate_deploy_key, [ "PRIVATE KEY", "PUBLIC KEY" ]) do
      creator.create_deploy_key!(repo)
    end

    assert_equal "12345", deploy_key.id
    assert_equal "PRIVATE KEY", deploy_key.private_key
    assert_requested request
  end

  test "commits identity, credentials, and deploy files" do
    repo = repo_result
    requests = stub_request(:put, %r{\Ahttps://api\.github\.com/repos/octocat/research-agent/contents/})
      .to_return(status: 201, body: { content: { path: "file" } }.to_json)

    creator.commit_runtime_files!(
      repo,
      identity_files: {
        "soul.md" => "# Soul",
        "memory/.keep" => ""
      },
      credentials_yml_enc: "encrypted",
      deploy_yml: "agent_id: research"
    )

    assert_requested requests, times: 3
    assert_requested :put, "https://api.github.com/repos/octocat/research-agent/contents/identity/soul.md"
    assert_requested :put, "https://api.github.com/repos/octocat/research-agent/contents/credentials.yml.enc"
    assert_requested :put, "https://api.github.com/repos/octocat/research-agent/contents/deploy.yml"
  end

  private

  def creator
    @creator ||= AgentRepoCreator.new(account: @account, agent: @agent, repo_name: "research-agent")
  end

  def repo_result
    AgentRepoCreator::Result.new(
      owner: "octocat",
      name: "research-agent",
      html_url: "https://github.com/octocat/research-agent",
      ssh_url: "git@github.com:octocat/research-agent.git",
      clone_url: "https://github.com/octocat/research-agent.git",
      default_branch: "main"
    )
  end

  def repo_response
    {
      owner: { login: "octocat" },
      name: "research-agent",
      html_url: "https://github.com/octocat/research-agent",
      ssh_url: "git@github.com:octocat/research-agent.git",
      clone_url: "https://github.com/octocat/research-agent.git",
      default_branch: "main"
    }
  end

end
