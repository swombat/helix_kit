class GithubCommitsTool < RubyLLM::Tool

  MAX_COMMITS = 50
  DEFAULT_COMMITS = 10

  description "Fetch recent GitHub commit messages and timestamps from the linked repository."

  param :count, type: :integer,
        desc: "Number of commits to fetch (1-#{MAX_COMMITS}, default #{DEFAULT_COMMITS})",
        required: false

  def initialize(chat: nil, current_agent: nil)
    super()
    @chat = chat
  end

  def execute(count: DEFAULT_COMMITS)
    count = count.to_i.clamp(1, MAX_COMMITS)

    integration = @chat&.account&.github_integration
    return { type: "error", error: "No GitHub integration configured" } unless integration&.enabled?
    return { type: "error", error: "No repository linked" } unless integration.repository_full_name.present?

    commits = integration.formatted_commits(limit: count)

    {
      type: "github_commits",
      repository: integration.repository_full_name,
      commits: commits,
      synced_at: integration.commits_synced_at&.iso8601
    }
  end

end
