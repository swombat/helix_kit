require "test_helper"

class GithubIntegrationTest < ActiveSupport::TestCase

  setup do
    @account = accounts(:team_account)
    @integration = GithubIntegration.create!(account: @account)
  end

  # --- Validations ---

  test "validates uniqueness of account" do
    duplicate = GithubIntegration.new(account: @account)
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:account_id], "has already been taken"
  end

  test "validates repository_full_name format with valid names" do
    valid_names = ["owner/repo", "my-org/my-repo", "user.name/repo.name", "org/repo-with-dashes"]
    valid_names.each do |name|
      @integration.repository_full_name = name
      assert @integration.valid?, "Expected '#{name}' to be valid"
    end
  end

  test "validates repository_full_name format rejects invalid names" do
    invalid_names = ["noslash", "owner/", "/repo", "owner/repo/extra", "owner repo", "owner//repo"]
    invalid_names.each do |name|
      @integration.repository_full_name = name
      assert_not @integration.valid?, "Expected '#{name}' to be invalid"
    end
  end

  test "allows nil repository_full_name" do
    @integration.repository_full_name = nil
    assert @integration.valid?
  end

  # --- Scopes ---

  test "enabled scope returns only enabled integrations" do
    @integration.update!(enabled: true)
    disabled = GithubIntegration.create!(account: accounts(:another_team), enabled: false)

    enabled = GithubIntegration.enabled
    assert_includes enabled, @integration
    assert_not_includes enabled, disabled
  end

  test "needs_sync scope returns enabled integrations with repo and stale sync" do
    @integration.update!(
      enabled: true,
      access_token: "token",
      repository_full_name: "owner/repo",
      commits_synced_at: 2.hours.ago
    )

    assert_includes GithubIntegration.needs_sync, @integration
  end

  test "needs_sync scope excludes recently synced integrations" do
    @integration.update!(
      enabled: true,
      access_token: "token",
      repository_full_name: "owner/repo",
      commits_synced_at: 30.minutes.ago
    )

    assert_not_includes GithubIntegration.needs_sync, @integration
  end

  test "needs_sync scope includes integrations that have never synced" do
    @integration.update!(
      enabled: true,
      access_token: "token",
      repository_full_name: "owner/repo",
      commits_synced_at: nil
    )

    assert_includes GithubIntegration.needs_sync, @integration
  end

  test "needs_sync scope excludes integrations without repo" do
    @integration.update!(
      enabled: true,
      access_token: "token",
      repository_full_name: nil,
      commits_synced_at: nil
    )

    assert_not_includes GithubIntegration.needs_sync, @integration
  end

  test "needs_sync scope excludes disabled integrations" do
    @integration.update!(
      enabled: false,
      access_token: "token",
      repository_full_name: "owner/repo",
      commits_synced_at: 2.hours.ago
    )

    assert_not_includes GithubIntegration.needs_sync, @integration
  end

  # --- connected? ---

  test "connected? returns true with access token" do
    @integration.update!(access_token: "ghp_token123")
    assert @integration.connected?
  end

  test "connected? returns false without access token" do
    assert_not @integration.connected?
  end

  # --- ready_to_sync? ---

  test "ready_to_sync? returns true when connected and repo present" do
    @integration.update!(access_token: "token", repository_full_name: "owner/repo")
    assert @integration.ready_to_sync?
  end

  test "ready_to_sync? returns false when not connected" do
    @integration.update!(repository_full_name: "owner/repo")
    assert_not @integration.ready_to_sync?
  end

  test "ready_to_sync? returns false when no repo" do
    @integration.update!(access_token: "token")
    assert_not @integration.ready_to_sync?
  end

  # --- commits_context ---

  test "commits_context returns formatted string when enabled with commits" do
    @integration.update!(
      enabled: true,
      repository_full_name: "owner/repo",
      recent_commits: [
        { "sha" => "abc12345", "date" => "2026-02-05T10:00:00Z", "message" => "Fix bug", "author" => "Dev" }
      ]
    )

    context = @integration.commits_context
    assert_includes context, "# Recent Commits to owner/repo"
    assert_includes context, "- abc12345 2026-02-05T10:00:00Z: Fix bug (Dev)"
  end

  test "commits_context returns nil when disabled" do
    @integration.update!(
      enabled: false,
      recent_commits: [{ "sha" => "abc", "date" => "2026-02-05", "message" => "Test", "author" => "Dev" }]
    )

    assert_nil @integration.commits_context
  end

  test "commits_context returns nil when no commits" do
    @integration.update!(enabled: true, recent_commits: [])
    assert_nil @integration.commits_context
  end

  test "commits_context formats multiple commits" do
    @integration.update!(
      enabled: true,
      repository_full_name: "org/project",
      recent_commits: [
        { "sha" => "aaaa1111", "date" => "2026-02-05", "message" => "First commit", "author" => "Alice" },
        { "sha" => "bbbb2222", "date" => "2026-02-04", "message" => "Second commit", "author" => "Bob" }
      ]
    )

    context = @integration.commits_context
    assert_includes context, "First commit (Alice)"
    assert_includes context, "Second commit (Bob)"
  end

  # --- disconnect! ---

  test "disconnect! clears token, repo, commits, and sync timestamp" do
    @integration.update!(
      access_token: "token",
      github_username: "testuser",
      repository_full_name: "owner/repo",
      recent_commits: [{ "sha" => "abc" }],
      commits_synced_at: Time.current
    )

    @integration.disconnect!

    assert_nil @integration.access_token
    assert_nil @integration.repository_full_name
    assert_equal [], @integration.recent_commits
    assert_nil @integration.commits_synced_at
  end

  test "disconnect! preserves github_username" do
    @integration.update!(
      access_token: "token",
      github_username: "testuser",
      repository_full_name: "owner/repo"
    )

    @integration.disconnect!

    assert_equal "testuser", @integration.github_username
  end

  # --- sync_commits! ---

  test "sync_commits! does nothing when not ready to sync" do
    assert_not @integration.ready_to_sync?

    @integration.sync_commits!

    assert_nil @integration.commits_synced_at
  end

  test "sync_commits! fetches and stores commits when ready" do
    @integration.update!(access_token: "token", repository_full_name: "owner/repo")

    fake_commits = [{ "sha" => "abc12345", "message" => "Test", "author" => "Dev", "date" => "2026-02-05" }]

    @integration.stub(:fetch_recent_commits, fake_commits) do
      @integration.sync_commits!
    end

    assert_equal fake_commits, @integration.recent_commits
    assert_not_nil @integration.commits_synced_at
  end

  # --- commits_context recency labels ---

  test "commits_context marks commits less than 1 hour old as JUST DEPLOYED" do
    @integration.update!(
      enabled: true,
      repository_full_name: "owner/repo",
      recent_commits: [
        { "sha" => "abc12345", "date" => 30.minutes.ago.iso8601, "message" => "Hot fix", "author" => "Dev" }
      ]
    )

    assert_includes @integration.commits_context, "[JUST DEPLOYED]"
  end

  test "commits_context marks commits less than 12 hours old as RECENTLY DEPLOYED" do
    @integration.update!(
      enabled: true,
      repository_full_name: "owner/repo",
      recent_commits: [
        { "sha" => "abc12345", "date" => 6.hours.ago.iso8601, "message" => "Feature", "author" => "Dev" }
      ]
    )

    context = @integration.commits_context
    assert_includes context, "[RECENTLY DEPLOYED]"
    assert_not_includes context, "[JUST DEPLOYED]"
  end

  test "commits_context does not mark old commits" do
    @integration.update!(
      enabled: true,
      repository_full_name: "owner/repo",
      recent_commits: [
        { "sha" => "abc12345", "date" => 2.days.ago.iso8601, "message" => "Old change", "author" => "Dev" }
      ]
    )

    context = @integration.commits_context
    assert_not_includes context, "DEPLOYED"
  end

  # --- formatted_commits ---

  test "formatted_commits returns limited commits with recency" do
    @integration.update!(
      enabled: true,
      recent_commits: [
        { "sha" => "aaa", "date" => 30.minutes.ago.iso8601, "message" => "First", "author" => "Alice" },
        { "sha" => "bbb", "date" => 6.hours.ago.iso8601, "message" => "Second", "author" => "Bob" },
        { "sha" => "ccc", "date" => 2.days.ago.iso8601, "message" => "Third", "author" => "Carol" }
      ]
    )

    results = @integration.formatted_commits(limit: 2)
    assert_equal 2, results.length
    assert_equal "JUST DEPLOYED", results[0][:recency]
    assert_equal "RECENTLY DEPLOYED", results[1][:recency]
  end

  test "formatted_commits returns empty array when disabled" do
    @integration.update!(enabled: false, recent_commits: [{ "sha" => "a", "date" => "2026-01-01", "message" => "x", "author" => "y" }])
    assert_equal [], @integration.formatted_commits(limit: 10)
  end

  test "formatted_commits returns empty array when no commits" do
    @integration.update!(enabled: true, recent_commits: [])
    assert_equal [], @integration.formatted_commits(limit: 10)
  end

  test "formatted_commits omits nil recency" do
    @integration.update!(
      enabled: true,
      recent_commits: [
        { "sha" => "aaa", "date" => 2.days.ago.iso8601, "message" => "Old", "author" => "Dev" }
      ]
    )

    result = @integration.formatted_commits(limit: 1).first
    assert_not result.key?(:recency)
  end

  # --- belongs_to account ---

  test "belongs to account" do
    assert_equal @account, @integration.account
  end

end
