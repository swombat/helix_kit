require "test_helper"

class SyncGithubCommitsJobTest < ActiveJob::TestCase

  setup do
    @account = accounts(:team_account)
    @integration = GithubIntegration.create!(
      account: @account,
      access_token: "ghp_test_token",
      github_username: "testuser",
      repository_full_name: "owner/repo"
    )
  end

  test "syncs commits on the integration" do
    fake_commits = [{ "sha" => "abc12345", "message" => "Test", "author" => "Dev", "date" => "2026-02-05" }]

    GithubIntegration.stub(:find, @integration) do
      @integration.stub(:fetch_recent_commits, fake_commits) do
        SyncGithubCommitsJob.perform_now(@integration.id)
      end
    end

    assert_equal fake_commits, @integration.recent_commits
    assert_not_nil @integration.commits_synced_at
  end

  test "enqueues on default queue" do
    assert_equal "default", SyncGithubCommitsJob.new.queue_name
  end

  test "enqueues with integration id" do
    assert_enqueued_with(job: SyncGithubCommitsJob, args: [@integration.id]) do
      SyncGithubCommitsJob.perform_later(@integration.id)
    end
  end

  test "raises RecordNotFound for missing integration" do
    assert_raises(ActiveRecord::RecordNotFound) do
      SyncGithubCommitsJob.perform_now(999999)
    end
  end

  test "retries on GithubApi::Error" do
    GithubIntegration.stub(:find, ->(_id) { raise GithubApi::Error, "token revoked" }) do
      assert_enqueued_with(job: SyncGithubCommitsJob) do
        SyncGithubCommitsJob.perform_now(@integration.id)
      end
    end
  end

  test "does nothing when integration is not ready to sync" do
    @integration.update!(access_token: nil, repository_full_name: nil)

    SyncGithubCommitsJob.perform_now(@integration.id)

    @integration.reload
    assert_nil @integration.commits_synced_at
  end

end
