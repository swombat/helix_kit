class GithubIntegration < ApplicationRecord

  include GithubApi

  belongs_to :account

  validates :account_id, uniqueness: true
  validates :repository_full_name, format: { with: /\A[\w\-\.]+\/[\w\-\.]+\z/ }, allow_nil: true

  scope :enabled, -> { where(enabled: true) }
  scope :needs_sync, -> { enabled.where.not(repository_full_name: nil).where("commits_synced_at IS NULL OR commits_synced_at < ?", 1.hour.ago) }

  def self.sync_all_due!
    needs_sync.find_each { |i| SyncGithubCommitsJob.perform_later(i.id) }
  end

  def ready_to_sync?
    connected? && repository_full_name.present?
  end

  def sync_commits!
    return unless ready_to_sync?

    update!(
      recent_commits: fetch_recent_commits,
      commits_synced_at: Time.current
    )
  end

  def commits_context
    return unless enabled? && recent_commits.present?

    lines = recent_commits.map do |c|
      "- #{c['sha']} #{c['date']}: #{c['message']} (#{c['author']})"
    end

    "# Recent Commits to #{repository_full_name}\n\n#{lines.join("\n")}"
  end

  def disconnect!
    update!(
      access_token: nil,
      repository_full_name: nil,
      recent_commits: [],
      commits_synced_at: nil
    )
  end

end
