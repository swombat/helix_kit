class ExternalAgentResponseRequest

  def initialize(agent:, chat:, requested_by: "HelixKit", initiation_reason: nil)
    @agent = agent
    @chat = chat
    @requested_by = requested_by
    @initiation_reason = initiation_reason
  end

  def call
    return notify_unreachable if agent.offline? || agent_unhealthy?

    endpoint_url = Agents::Endpoint.url_for(agent)
    session_id = "#{agent.uuid}-#{chat.id}"
    request = request_text

    AgentRuntimeInteraction.record_trigger!(
      agent: agent,
      chat: chat,
      trigger_kind: "conversation",
      conversation_id: chat.to_param,
      requested_by: requested_by,
      session_id: session_id,
      endpoint_url: endpoint_url,
      request_text: request
    ) do
      ChaosTriggerClient.new(endpoint_url, agent.trigger_bearer_token).request_response(
        conversation_id: chat.to_param,
        requested_by: requested_by,
        session_id: session_id,
        request: request
      )
    end
  rescue StandardError => e
    Rails.logger.warn "[ExternalAgentResponseRequest] #{agent.id} trigger failed: #{e.class}: #{e.message}"
    ActionCable.server.broadcast(
      "Chat:#{chat.to_param}",
      { action: "error", message: "#{agent.name}'s external runtime could not be reached" }
    )
    { status: 0, error: e.message }
  end

  private

  attr_reader :agent, :chat, :requested_by, :initiation_reason

  def agent_unhealthy?
    agent.health_state == "unhealthy" && agent.consecutive_health_failures >= 6
  end

  def notify_unreachable
    chat.messages.create!(
      role: "assistant",
      agent: agent,
      content: "_#{agent.name} is currently unreachable on its external runtime._"
    )
    { status: 503, error: "external runtime unreachable" }
  end

  def request_text
    parts = [
      "HelixKit received an explicit user request for you to consider responding to conversation #{chat.to_param}. The user pressed the agent button, so they are normally expecting a visible reply from you.",
      "Requested by: #{requested_by}.",
      "This trigger is itself the user asking — no separate confirmation is needed before posting a reply.",
      "Important: your final answer in this Chaos runtime is diagnostic stdout only; it will not appear in the HelixKit chat. If you have a message for the user, you must post it to HelixKit yourself before exiting.",
      "Decide whether to respond. The default for this trigger is that you post a reply, but choosing not to is also a valid response. If you choose to respond, post it to this conversation now. Prefer the helper command: `helixkit-post-message #{chat.to_param} \"your message\"` (or pipe longer Markdown into it). You may also use the API described in ~/identity/helixkit-api.md with HELIXKIT_APP_URL and HELIXKIT_BEARER_TOKEN.",
      "HELIXKIT_APP_URL and HELIXKIT_BEARER_TOKEN are already present in your shell environment. The bearer token is already authorized for you to read this conversation and post your own messages; do not ask Daniel to paste it or re-authorize it.",
      "Do not rely on stdout as the response channel; stdout is diagnostic only. If you choose not to respond, explain your reason briefly on stdout and then exit without posting.",
      conversation_context
    ]
    parts << "Initiation reason: #{initiation_reason}" if initiation_reason.present?
    parts.join("\n\n")
  end

  def conversation_context
    lines = chat.messages.order(:created_at).last(30).map do |message|
      speaker = if message.agent
        message.agent.name
      elsif message.user
        message.user.email_address
      else
        message.role
      end

      "#{speaker}: #{message.content.to_s.strip}"
    end

    return "Conversation transcript: _No messages yet._" if lines.empty?

    "Conversation transcript:\n\n#{lines.join("\n\n")}"
  end

end
