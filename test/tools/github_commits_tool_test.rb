require "test_helper"

class GithubCommitsToolTest < ActiveSupport::TestCase

  setup do
    @account = accounts(:team_account)
    @chat = @account.chats.create!(model_id: "openai/gpt-4o")
    @agent = agents(:research_assistant)
  end

  test "returns error for invalid action" do
    result = build_tool.execute(action: "invalid")

    assert_equal "error", result[:type]
    assert_match(/Invalid action/, result[:error])
    assert_equal %w[fetch sync diff file], result[:allowed_actions]
  end

  test "returns error when no github integration configured" do
    result = build_tool.execute(action: "fetch")

    assert_equal "error", result[:type]
    assert_match(/No GitHub integration/, result[:error])
  end

  test "returns error when integration is disabled" do
    create_integration(enabled: false,
      recent_commits: [ { "sha" => "abc", "message" => "Test", "author" => "Dev", "date" => 1.hour.ago.iso8601 } ])

    result = build_tool.execute(action: "fetch")

    assert_equal "error", result[:type]
  end

  test "returns error when no repository linked" do
    create_integration(repository_full_name: nil)

    result = build_tool.execute(action: "fetch")

    assert_equal "error", result[:type]
    assert_match(/No repository linked/, result[:error])
  end

  test "fetch returns cached commits with default count" do
    create_integration(
      commits_synced_at: 10.minutes.ago,
      recent_commits: Array.new(15) { |i|
        { "sha" => "sha#{i}", "message" => "Commit #{i}", "author" => "Dev", "date" => i.hours.ago.iso8601 }
      }
    )

    result = build_tool.execute(action: "fetch")

    assert_equal "github_commits", result[:type]
    assert_equal "owner/repo", result[:repository]
    assert_equal 10, result[:commits].length
    assert_equal false, result[:freshly_synced]
  end

  test "fetch returns commits with custom count" do
    create_integration(
      commits_synced_at: 10.minutes.ago,
      recent_commits: Array.new(20) { |i|
        { "sha" => "sha#{i}", "message" => "Commit #{i}", "author" => "Dev", "date" => i.hours.ago.iso8601 }
      }
    )

    result = build_tool.execute(action: "fetch", count: 5)

    assert_equal 5, result[:commits].length
  end

  test "clamps count to MAX_COMMITS" do
    create_integration(
      commits_synced_at: 10.minutes.ago,
      recent_commits: Array.new(60) { |i|
        { "sha" => "sha#{i}", "message" => "Commit #{i}", "author" => "Dev", "date" => i.hours.ago.iso8601 }
      }
    )

    result = build_tool.execute(action: "fetch", count: 100)

    assert_equal 50, result[:commits].length
  end

  test "includes recency labels in commits" do
    create_integration(
      commits_synced_at: 10.minutes.ago,
      recent_commits: [
        { "sha" => "aaa", "message" => "Just now", "author" => "Dev", "date" => 10.minutes.ago.iso8601 }
      ]
    )

    result = build_tool.execute(action: "fetch")

    assert_equal "JUST DEPLOYED", result[:commits].first[:recency]
  end

  test "sync calls sync_commits! and returns fresh data" do
    integration = create_integration(
      commits_synced_at: 2.hours.ago,
      recent_commits: [
        { "sha" => "old", "message" => "Old commit", "author" => "Dev", "date" => 2.hours.ago.iso8601 }
      ]
    )

    new_commits = [
      { "sha" => "new123", "message" => "Fresh commit", "author" => "Dev", "date" => 5.minutes.ago.iso8601 }
    ]

    integration.stub(:fetch_recent_commits, new_commits) do
      result = build_tool.execute(action: "sync")

      assert_equal "github_commits", result[:type]
      assert_equal true, result[:freshly_synced]
      assert_equal "new123", result[:commits].first[:sha]
    end
  end

  test "diff returns error when sha is missing" do
    create_integration

    result = build_tool.execute(action: "diff")

    assert_equal "error", result[:type]
    assert_match(/sha is required/, result[:error])
  end

  test "diff returns commit diff" do
    integration = create_integration
    diff_text = "diff --git a/file.rb b/file.rb\n+new line\n"

    integration.stub(:fetch_commit_diff, diff_text) do
      result = build_tool.execute(action: "diff", sha: "abc123")

      assert_equal "github_diff", result[:type]
      assert_equal "owner/repo", result[:repository]
      assert_equal "abc123", result[:sha]
      assert_equal diff_text, result[:diff]
      assert_equal false, result[:truncated]
    end
  end

  test "diff truncates large diffs" do
    integration = create_integration
    huge_diff = "x" * 60_000

    integration.stub(:fetch_commit_diff, huge_diff) do
      result = build_tool.execute(action: "diff", sha: "abc123")

      assert_equal "github_diff", result[:type]
      assert_equal GithubCommitsTool::MAX_DIFF_SIZE, result[:diff].size
      assert_equal true, result[:truncated]
    end
  end

  test "diff returns error when fetch fails" do
    integration = create_integration

    integration.stub(:fetch_commit_diff, nil) do
      result = build_tool.execute(action: "diff", sha: "nonexistent")

      assert_equal "error", result[:type]
      assert_match(/Could not fetch diff/, result[:error])
    end
  end

  test "file returns error when path is missing" do
    create_integration

    result = build_tool.execute(action: "file")

    assert_equal "error", result[:type]
    assert_match(/path is required/, result[:error])
  end

  test "file returns file contents" do
    integration = create_integration
    file_contents = "class Foo\n  def bar\n    42\n  end\nend\n"

    integration.stub(:fetch_file_contents, file_contents) do
      result = build_tool.execute(action: "file", path: "app/models/foo.rb")

      assert_equal "github_file", result[:type]
      assert_equal "owner/repo", result[:repository]
      assert_equal "app/models/foo.rb", result[:path]
      assert_equal file_contents, result[:contents]
      assert_equal false, result[:truncated]
    end
  end

  test "file truncates large files" do
    integration = create_integration
    huge_file = "x" * 150_000

    integration.stub(:fetch_file_contents, huge_file) do
      result = build_tool.execute(action: "file", path: "big_file.txt")

      assert_equal "github_file", result[:type]
      assert_equal GithubCommitsTool::MAX_FILE_SIZE, result[:contents].size
      assert_equal true, result[:truncated]
    end
  end

  test "file returns error when fetch fails" do
    integration = create_integration

    integration.stub(:fetch_file_contents, nil) do
      result = build_tool.execute(action: "file", path: "nonexistent.rb")

      assert_equal "error", result[:type]
      assert_match(/Could not fetch file/, result[:error])
    end
  end

  private

  def create_integration(**overrides)
    defaults = { account: @account, enabled: true, repository_full_name: "owner/repo", access_token: "token" }
    GithubIntegration.create!(**defaults.merge(overrides))
  end

  def build_tool
    GithubCommitsTool.new(chat: @chat, current_agent: @agent)
  end

end
