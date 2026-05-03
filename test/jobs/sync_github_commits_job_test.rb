require "test_helper"

class SyncGithubCommitsJobTest < ActiveJob::TestCase

  setup do
    @account = accounts(:team_account)
    @integration = GithubIntegration.create!(
      account: @account,
      access_token: github_test_access_token,
      github_username: "testuser",
      repository_full_name: "rails/rails"
    )
  end

  test "syncs commits on the integration" do
    VCR.use_cassette("jobs/sync_github_commits_job/syncs_rails_commits") do
      SyncGithubCommitsJob.perform_now(@integration.id)
    end

    @integration.reload
    assert_not_empty @integration.recent_commits
    assert_not_nil @integration.commits_synced_at
  end

  test "enqueues on default queue" do
    assert_equal "default", SyncGithubCommitsJob.new.queue_name
  end

  test "enqueues with integration id" do
    assert_enqueued_with(job: SyncGithubCommitsJob, args: [ @integration.id ]) do
      SyncGithubCommitsJob.perform_later(@integration.id)
    end
  end

  test "raises RecordNotFound for missing integration" do
    assert_raises(ActiveRecord::RecordNotFound) do
      SyncGithubCommitsJob.perform_now(999999)
    end
  end

  test "does nothing when integration is not ready to sync" do
    @integration.update!(access_token: nil, repository_full_name: nil)

    SyncGithubCommitsJob.perform_now(@integration.id)

    @integration.reload
    assert_nil @integration.commits_synced_at
  end

  private

  def github_test_access_token
    ENV.fetch("GITHUB_TEST_ACCESS_TOKEN", "ghp_test_token")
  end

end
