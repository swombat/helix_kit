class GithubIntegration < ApplicationRecord

  include GithubApi

  belongs_to :account

  validates :account_id, uniqueness: true
  validates :repository_full_name, format: { with: /\A[\w\-\.]+\/[\w\-\.]+\z/ }, allow_nil: true

  scope :enabled, -> { where(enabled: true) }
  scope :needs_sync, -> { enabled.where.not(repository_full_name: nil).where("commits_synced_at IS NULL OR commits_synced_at < ?", 45.minutes.ago) }

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

    now = Time.current
    lines = recent_commits.map do |c|
      recency = commit_recency_label(c["date"], now)
      prefix = recency ? " [#{recency}]" : ""
      "- #{c['sha']} #{c['date']}: #{c['message']} (#{c['author']})#{prefix}"
    end

    "# Recent Commits to #{repository_full_name}\n\n#{lines.join("\n")}"
  end

  def formatted_commits(limit:)
    return [] unless enabled? && recent_commits.present?

    now = Time.current
    recent_commits.first(limit).map do |c|
      recency = commit_recency_label(c["date"], now)
      { sha: c["sha"], message: c["message"], author: c["author"], date: c["date"], recency: recency }.compact
    end
  end

  def disconnect!
    update!(
      access_token: nil,
      repository_full_name: nil,
      recent_commits: [],
      commits_synced_at: nil
    )
  end

  private

  def commit_recency_label(date_string, now = Time.current)
    return unless date_string.present?

    commit_time = Time.parse(date_string) rescue return
    hours_ago = (now - commit_time) / 1.hour

    if hours_ago < 1
      "JUST DEPLOYED"
    elsif hours_ago < 12
      "RECENTLY DEPLOYED"
    end
  end

end
