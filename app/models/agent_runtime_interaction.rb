class AgentRuntimeInteraction < ApplicationRecord

  belongs_to :agent
  belongs_to :chat, optional: true
  after_commit :broadcast_agent_runtime_interactions_refresh, on: [ :create, :update, :destroy ]

  validates :trigger_kind, presence: true
  validates :started_at, presence: true

  scope :recent, -> { order(created_at: :desc) }
  scope :timeline_order, -> { order(Arel.sql("COALESCE(finished_at, started_at, created_at) ASC"), :id) }

  def self.record_trigger!(agent:, chat:, trigger_kind:, conversation_id:, requested_by:, session_id:, endpoint_url:, request_text:, last_included_message_id: nil)
    interaction = create!(
      agent: agent,
      chat: chat,
      trigger_kind: trigger_kind,
      conversation_obfuscated_id: conversation_id,
      requested_by: requested_by,
      session_id: session_id,
      endpoint_url: endpoint_url,
      request_text: request_text,
      last_included_message_id: last_included_message_id,
      started_at: Time.current
    )

    result = yield
    interaction.record_result!(result)
    result
  rescue StandardError => e
    interaction&.record_error!(e)
    raise
  end

  def record_result!(result)
    body = result[:body] || {}
    full_invocation_text = body.delete("full_invocation_text")
    usage = body["usage"] || {}

    update!(
      transport_status: result[:status],
      runtime_status: body["status"],
      runtime_returncode: body["returncode"],
      stdout: body["stdout"],
      stderr: body["stderr"],
      full_invocation_text: full_invocation_text,
      chaos_session_id: body["chaos_session_id"],
      session_resumed: body["session_resumed"],
      fresh_fallback: body["fresh_fallback"],
      input_tokens: usage["input_tokens"],
      cached_input_tokens: usage["cached_input_tokens"],
      output_tokens: usage["output_tokens"],
      response_body: body,
      finished_at: Time.current,
      duration_ms: elapsed_ms
    )
  end

  def record_error!(error)
    update!(
      error_class: error.class.name,
      error_message: error.message,
      finished_at: Time.current,
      duration_ms: elapsed_ms
    )
  end

  def as_debug_json
    {
      id: id,
      trigger_kind: trigger_kind,
      session_id: session_id,
      conversation_id: conversation_obfuscated_id,
      requested_by: requested_by,
      endpoint_url: endpoint_url,
      transport_status: transport_status,
      runtime_status: runtime_status,
      runtime_returncode: runtime_returncode,
      stdout: stdout,
      stderr: stderr,
      error_class: error_class,
      error_message: error_message,
      chaos_session_id: chaos_session_id,
      session_resumed: session_resumed,
      fresh_fallback: fresh_fallback,
      input_tokens: input_tokens,
      cached_input_tokens: cached_input_tokens,
      output_tokens: output_tokens,
      started_at: started_at&.iso8601,
      finished_at: finished_at&.iso8601,
      duration_ms: duration_ms,
      created_at: created_at&.iso8601
    }
  end

  def as_chat_activity_json
    {
      id: to_param,
      agent_id: agent.to_param,
      agent_name: agent.name,
      agent_icon: agent.icon,
      agent_colour: agent.colour,
      trigger_kind: trigger_kind,
      status: chat_activity_status,
      status_label: chat_activity_status_label,
      conversation_id: conversation_obfuscated_id,
      transport_status: transport_status,
      runtime_status: runtime_status,
      runtime_returncode: runtime_returncode,
      stdout: stdout,
      stderr: stderr,
      error_class: error_class,
      error_message: error_message,
      started_at: started_at&.iso8601,
      finished_at: finished_at&.iso8601,
      duration_ms: duration_ms,
      created_at: (finished_at || started_at || created_at)&.iso8601
    }
  end

  def visible_in_chat_timeline?
    !posted_assistant_message?
  end

  private

  def broadcast_agent_runtime_interactions_refresh
    ActionCable.server.broadcast(
      "Agent:#{agent.obfuscated_id}",
      { action: "refresh", prop: "runtime_interactions" }
    )

    return unless chat

    ActionCable.server.broadcast(
      "Chat:#{chat.obfuscated_id}",
      { action: "refresh", prop: "runtime_interactions" }
    )
  end

  def elapsed_ms
    return unless started_at

    ((Time.current - started_at) * 1000).round
  end

  def running?
    finished_at.blank?
  end

  def posted_assistant_message?
    return false unless chat && agent && started_at

    upper_bound = finished_at || Time.current
    chat.messages
      .where(role: "assistant", agent: agent)
      .where(created_at: started_at..(upper_bound + 30.seconds))
      .exists?
  end

  def chat_activity_status
    return "running" if running?
    return "failed" if error_message.present? || transport_status.to_i >= 400 || runtime_returncode.to_i.nonzero?

    "completed_without_reply"
  end

  def chat_activity_status_label
    case chat_activity_status
    when "running"
      "is running"
    when "failed"
      "finished with an error"
    else
      "completed without posting a reply"
    end
  end

end
