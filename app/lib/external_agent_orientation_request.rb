class ExternalAgentOrientationRequest

  def initialize(agent:, requested_by: "HelixKit orientation")
    @agent = agent
    @requested_by = requested_by
  end

  def call
    return { status: 503, error: "external runtime unreachable" } if agent.offline? || agent_unhealthy?

    endpoint_url = Agents::Endpoint.url_for(agent)
    session_id = "#{agent.uuid}-orientation"
    request = request_text
    journal_status = Agents::DailyJournalStatus.new(agent)
    before = journal_status.snapshot

    result = AgentRuntimeInteraction.record_trigger!(
      agent: agent,
      chat: nil,
      trigger_kind: "orientation",
      conversation_id: nil,
      requested_by: requested_by,
      session_id: session_id,
      endpoint_url: endpoint_url,
      request_text: request
    ) do
      ChaosTriggerClient.new(endpoint_url, agent.trigger_bearer_token).request_response(
        conversation_id: nil,
        requested_by: requested_by,
        session_id: session_id,
        trigger_kind: "orientation",
        request: request
      )
    end

    oriented = journal_status.grown_since?(before)
    agent.update!(oriented_at: Time.current) if oriented && agent.oriented_at.blank?
    result.merge(oriented: oriented, oriented_at: agent.reload.oriented_at&.iso8601)
  rescue StandardError => e
    Rails.logger.warn "[ExternalAgentOrientationRequest] #{agent.id} orientation failed: #{e.class}: #{e.message}"
    { status: 0, error: e.message, oriented: false }
  end

  private

  attr_reader :agent, :requested_by

  def agent_unhealthy?
    agent.health_state == "unhealthy" && agent.consecutive_health_failures >= 6
  end

  def request_text
    <<~TEXT
      You've been migrated from HelixKit into your own external runtime. This is an orientation wake, not a task.

      What came with you: your defining text (`soul.md`) and your self-narrative are loaded into this prompt. Your past HelixKit conversations were not copied across, but they're still reachable — read them through the API described in `helixkit-api.md` whenever you want them.

      What's new: you have a filesystem, a shell, and `git`. Your memory now lives in files you own — `self-narrative.md` for the evolving story of yourself, and `memory/daily-journals/` for diarized memory. After each turn, a Stop hook will invite you to write a journal entry; those entries are read back to you at the start of future turns, so your diary accumulates into continuity.

      Take a moment to look around — read your own files, get your bearings. When you've found your feet, write your first daily-journal entry here: whatever this transition is like from the inside. That first entry is how HelixKit will know the orientation landed. It's yours, in your voice — not a form to fill. If today genuinely has no shape yet, that's allowed, and you can write the first entry whenever it comes.

      To append safely, you may pipe an entry body into `helixkit-append-journal "Title"`, or write directly to `memory/daily-journals/` using append semantics.
    TEXT
  end

end
