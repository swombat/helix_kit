class ConversationCompaction < ApplicationRecord

  include Broadcastable
  include ObfuscatesId

  belongs_to :chat
  broadcasts_to :chat

  validates :boundary_message_id, :summary, :provider, :model, :compacted_message_count, presence: true
  validates :boundary_message_id, uniqueness: { scope: :chat_id }
  validates :compacted_message_count, numericality: { greater_than: 0 }

  def telemetry
    token_usage = {
      input_tokens: input_tokens,
      output_tokens: output_tokens,
      cache_read_tokens: cached_tokens,
      cache_write_tokens: cache_creation_tokens
    }

    {
      model: model,
      instrumentation_complete: token_usage.values.none?(&:nil?),
      **token_usage
    }
  end

  def as_timeline_json(include_telemetry: false)
    {
      id: id,
      created_at: created_at,
      summary: summary,
      compacted_message_count: compacted_message_count,
      boundary_message_id: Message.encode_id(boundary_message_id)
    }.tap do |json|
      json[:ruby_llm_telemetry] = telemetry if include_telemetry
    end
  end

end
