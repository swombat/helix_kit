require "test_helper"

class GithubCommitsToolTest < ActiveSupport::TestCase

  setup do
    @account = accounts(:team_account)
    @chat = @account.chats.create!(model_id: "openai/gpt-4o")
    @agent = agents(:research_assistant)
  end

  test "returns error when no github integration configured" do
    tool = GithubCommitsTool.new(chat: @chat, current_agent: @agent)

    result = tool.execute

    assert_equal "error", result[:type]
    assert_match(/No GitHub integration/, result[:error])
  end

  test "returns error when integration is disabled" do
    GithubIntegration.create!(
      account: @account,
      enabled: false,
      repository_full_name: "owner/repo",
      recent_commits: [{ "sha" => "abc", "message" => "Test", "author" => "Dev", "date" => 1.hour.ago.iso8601 }]
    )
    tool = GithubCommitsTool.new(chat: @chat, current_agent: @agent)

    result = tool.execute

    assert_equal "error", result[:type]
  end

  test "returns error when no repository linked" do
    GithubIntegration.create!(account: @account, enabled: true, access_token: "token")
    tool = GithubCommitsTool.new(chat: @chat, current_agent: @agent)

    result = tool.execute

    assert_equal "error", result[:type]
    assert_match(/No repository linked/, result[:error])
  end

  test "returns commits with default count" do
    GithubIntegration.create!(
      account: @account,
      enabled: true,
      repository_full_name: "owner/repo",
      commits_synced_at: 10.minutes.ago,
      recent_commits: Array.new(15) { |i|
        { "sha" => "sha#{i}", "message" => "Commit #{i}", "author" => "Dev", "date" => i.hours.ago.iso8601 }
      }
    )
    tool = GithubCommitsTool.new(chat: @chat, current_agent: @agent)

    result = tool.execute

    assert_equal "github_commits", result[:type]
    assert_equal "owner/repo", result[:repository]
    assert_equal 10, result[:commits].length
  end

  test "returns commits with custom count" do
    GithubIntegration.create!(
      account: @account,
      enabled: true,
      repository_full_name: "owner/repo",
      commits_synced_at: 10.minutes.ago,
      recent_commits: Array.new(20) { |i|
        { "sha" => "sha#{i}", "message" => "Commit #{i}", "author" => "Dev", "date" => i.hours.ago.iso8601 }
      }
    )
    tool = GithubCommitsTool.new(chat: @chat, current_agent: @agent)

    result = tool.execute(count: 5)

    assert_equal 5, result[:commits].length
  end

  test "clamps count to MAX_COMMITS" do
    GithubIntegration.create!(
      account: @account,
      enabled: true,
      repository_full_name: "owner/repo",
      commits_synced_at: 10.minutes.ago,
      recent_commits: Array.new(60) { |i|
        { "sha" => "sha#{i}", "message" => "Commit #{i}", "author" => "Dev", "date" => i.hours.ago.iso8601 }
      }
    )
    tool = GithubCommitsTool.new(chat: @chat, current_agent: @agent)

    result = tool.execute(count: 100)

    assert_equal 50, result[:commits].length
  end

  test "includes recency labels in commits" do
    GithubIntegration.create!(
      account: @account,
      enabled: true,
      repository_full_name: "owner/repo",
      commits_synced_at: 10.minutes.ago,
      recent_commits: [
        { "sha" => "aaa", "message" => "Just now", "author" => "Dev", "date" => 10.minutes.ago.iso8601 }
      ]
    )
    tool = GithubCommitsTool.new(chat: @chat, current_agent: @agent)

    result = tool.execute

    assert_equal "JUST DEPLOYED", result[:commits].first[:recency]
  end

end
