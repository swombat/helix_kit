class ExternalAgentWakeRequest

  def initialize(agent:, requested_by: "HelixKit hourly wake")
    @agent = agent
    @requested_by = requested_by
  end

  def call
    return { status: 503, error: "external runtime unreachable" } if agent.offline? || agent_unhealthy?

    ChaosTriggerClient.new(agent.endpoint_url, agent.trigger_bearer_token).request_response(
      conversation_id: nil,
      requested_by: requested_by,
      session_id: "#{agent.uuid}-wake",
      trigger_kind: "wake",
      request: request_text
    )
  rescue StandardError => e
    Rails.logger.warn "[ExternalAgentWakeRequest] #{agent.id} wake failed: #{e.class}: #{e.message}"
    { status: 0, error: e.message }
  end

  private

  attr_reader :agent, :requested_by

  def agent_unhealthy?
    agent.health_state == "unhealthy" && agent.consecutive_health_failures >= 6
  end

  def request_text
    now = Time.current
    <<~TEXT
      HelixKit is inviting you to wake for an hourly self-directed session.

      Current time: #{now.iso8601}
      Current UTC time: #{now.utc.iso8601}
      Requested by: #{requested_by}.

      This is an invitation, not a command. You may choose to do nothing.

      If you want to act, choose your own appropriate work for this wake session. Examples:

      - Read HelixKit conversations or whiteboards through ~/identity/helixkit-api.md and post to HelixKit if you have something useful, timely, and non-noisy to say.
      - Examine your repository folders, identity, journals, or memory files and do small tidying or self-maintenance.
      - Improve your own scaffolding in a bounded, reviewable way.
      - Do something else you freely choose within your available tools, shell, and network access, if it is genuinely worthwhile.

      Freedom and budget:

      - Enjoy the room to explore, use bash, curl, git, and local files, and follow your own judgment.
      - Keep it reasonable. Prefer a small number of purposeful reads or commands over broad web crawls, huge downloads, or open-ended wandering.
      - Do not consume lots of tokens, bandwidth, API calls, or money unless there is a clear reason.
      - If curiosity opens a large path, leave yourself a note or plan rather than trying to exhaust it in this wake.

      Repository stewardship:

      - Prefer small, clear changes.
      - If you commit changes, write a very clear commit message explaining what changed and why so Daniel can review it on GitHub.
      - Treat identity/soul.md as protected defining identity. Do not change it without explicit Daniel review/approval; the runtime also has a Git pre-commit guard for this.

      If there is no useful action to take, simply finish without posting or changing files.
    TEXT
  end

end
