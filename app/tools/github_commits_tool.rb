class GithubCommitsTool < RubyLLM::Tool

  MAX_COMMITS = 50
  DEFAULT_COMMITS = 10
  ACTIONS = %w[fetch sync].freeze

  description "Fetch or sync GitHub commits. Actions: fetch (read cached commits), sync (force fresh sync from GitHub then return commits)."

  param :action, type: :string,
        desc: "fetch or sync",
        required: true

  param :count, type: :integer,
        desc: "Number of commits to return (1-#{MAX_COMMITS}, default #{DEFAULT_COMMITS})",
        required: false

  def initialize(chat: nil, current_agent: nil)
    super()
    @chat = chat
  end

  def execute(action: "fetch", count: DEFAULT_COMMITS)
    return { type: "error", error: "Invalid action '#{action}'", allowed_actions: ACTIONS } unless ACTIONS.include?(action)

    integration = @chat&.account&.github_integration
    return { type: "error", error: "No GitHub integration configured" } unless integration&.enabled?
    return { type: "error", error: "No repository linked" } unless integration.repository_full_name.present?

    integration.sync_commits! if action == "sync"

    count = count.to_i.clamp(1, MAX_COMMITS)
    commits = integration.formatted_commits(limit: count)

    {
      type: "github_commits",
      repository: integration.repository_full_name,
      commits: commits,
      synced_at: integration.reload.commits_synced_at&.iso8601,
      freshly_synced: action == "sync"
    }
  end

end
