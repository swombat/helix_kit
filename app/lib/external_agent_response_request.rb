class ExternalAgentResponseRequest

  def initialize(agent:, chat:, requested_by: "HelixKit", initiation_reason: nil)
    @agent = agent
    @chat = chat
    @requested_by = requested_by
    @initiation_reason = initiation_reason
  end

  def call
    return notify_unreachable if agent.offline? || agent_unhealthy?

    ChaosTriggerClient.new(agent.endpoint_url, agent.trigger_bearer_token).request_response(
      conversation_id: chat.to_param,
      requested_by: requested_by,
      session_id: "#{agent.uuid}-#{chat.id}",
      request: request_text
    )
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
      "HelixKit received a request for you to consider responding to conversation #{chat.to_param}.",
      "Requested by: #{requested_by}.",
      "This is an invitation, not a command. To inspect the conversation, see ~/identity/helixkit-api.md (your HelixKit API reference). To respond, use the post-message endpoint described there. If you choose not to respond, do nothing."
    ]
    parts << "Initiation reason: #{initiation_reason}" if initiation_reason.present?
    parts.join("\n\n")
  end

end
