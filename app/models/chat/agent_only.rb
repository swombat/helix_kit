module Chat::AgentOnly

  extend ActiveSupport::Concern

  AGENT_ONLY_PREFIX = "[AGENT-ONLY]"

  included do
    scope :agent_only, -> { where("title LIKE ?", "#{AGENT_ONLY_PREFIX}%") }
    scope :not_agent_only, -> { where("title NOT LIKE ? OR title IS NULL", "#{AGENT_ONLY_PREFIX}%") }
  end

  def agent_only?
    title&.start_with?(AGENT_ONLY_PREFIX)
  end

  def agent_only
    agent_only?
  end

end
