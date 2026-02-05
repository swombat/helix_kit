class SyncGithubCommitsJob < ApplicationJob

  queue_as :default

  retry_on GithubApi::Error, wait: :polynomially_longer, attempts: 3

  def perform(github_integration_id)
    GithubIntegration.find(github_integration_id).sync_commits!
  rescue GithubApi::Error => e
    Rails.logger.error("GitHub sync failed for integration #{github_integration_id}: #{e.message}")
    raise
  end

end
