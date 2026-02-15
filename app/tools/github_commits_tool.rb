class GithubCommitsTool < RubyLLM::Tool

  MAX_COMMITS = 50
  DEFAULT_COMMITS = 10
  MAX_DIFF_SIZE = 50_000
  MAX_FILE_SIZE = 100_000
  ACTIONS = %w[fetch sync diff file].freeze

  description "Interact with GitHub. Actions: fetch (read cached commits), sync (force fresh sync from GitHub), diff (get diff for a commit SHA), file (get latest file contents)."

  param :action, type: :string,
        desc: "fetch, sync, diff, or file",
        required: true

  param :count, type: :integer,
        desc: "Number of commits to return (1-#{MAX_COMMITS}, default #{DEFAULT_COMMITS}). Used with fetch/sync.",
        required: false

  param :sha, type: :string,
        desc: "Commit SHA to fetch the diff for. Required for diff action.",
        required: false

  param :path, type: :string,
        desc: "File path within the repository. Required for file action.",
        required: false

  def initialize(chat: nil, current_agent: nil)
    super()
    @chat = chat
    @current_agent = current_agent
  end

  def execute(action: "fetch", count: DEFAULT_COMMITS, sha: nil, path: nil)
    return validation_error("Invalid action '#{action}'") unless ACTIONS.include?(action)

    integration = @chat&.account&.github_integration
    return validation_error("No GitHub integration configured") unless integration&.enabled?
    return validation_error("No repository linked") unless integration.repository_full_name.present?

    case action
    when "fetch", "sync" then execute_commits(integration, action, count)
    when "diff"          then execute_diff(integration, sha)
    when "file"          then execute_file(integration, path)
    end
  end

  private

  def execute_commits(integration, action, count)
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

  def execute_diff(integration, sha)
    return param_error("diff", "sha") unless sha.present?

    diff = integration.fetch_commit_diff(sha)
    return validation_error("Could not fetch diff for commit #{sha}") unless diff

    diff, truncated = truncate(diff, MAX_DIFF_SIZE)
    { type: "github_diff", repository: integration.repository_full_name, sha: sha, diff: diff, truncated: truncated }
  end

  def execute_file(integration, path)
    return param_error("file", "path") unless path.present?

    contents = integration.fetch_file_contents(path)
    return validation_error("Could not fetch file #{path}") unless contents

    contents, truncated = truncate(contents, MAX_FILE_SIZE)
    { type: "github_file", repository: integration.repository_full_name, path: path, contents: contents, truncated: truncated }
  end

  def truncate(content, max_size)
    truncated = content.size > max_size
    [ truncated ? content.first(max_size) : content, truncated ]
  end

  def validation_error(msg) = { type: "error", error: msg, allowed_actions: ACTIONS }
  def param_error(action, param) = { type: "error", error: "#{param} is required for #{action}", allowed_actions: ACTIONS }

end
