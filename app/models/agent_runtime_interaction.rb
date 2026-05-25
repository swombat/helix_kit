class AgentRuntimeInteraction < ApplicationRecord

  belongs_to :agent
  belongs_to :chat, optional: true

  validates :trigger_kind, presence: true
  validates :started_at, presence: true

  scope :recent, -> { order(created_at: :desc) }

  def self.record_trigger!(agent:, chat:, trigger_kind:, conversation_id:, requested_by:, session_id:, endpoint_url:, request_text:)
    interaction = create!(
      agent: agent,
      chat: chat,
      trigger_kind: trigger_kind,
      conversation_obfuscated_id: conversation_id,
      requested_by: requested_by,
      session_id: session_id,
      endpoint_url: endpoint_url,
      request_text: request_text,
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
    update!(
      transport_status: result[:status],
      runtime_status: body["status"],
      runtime_returncode: body["returncode"],
      stdout: body["stdout"],
      stderr: body["stderr"],
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
      started_at: started_at&.iso8601,
      finished_at: finished_at&.iso8601,
      duration_ms: duration_ms,
      created_at: created_at&.iso8601
    }
  end

  private

  def elapsed_ms
    return unless started_at

    ((Time.current - started_at) * 1000).round
  end

end
