class ConsolidateStaleConversationsJob < ApplicationJob

  IDLE_THRESHOLD = 6.hours
  def perform
    conversation_ids = stale_conversations.pluck(:id)

    over_budget_conversations.find_each do |chat|
      conversation_ids << chat.id if ConsolidateConversationJob.transcript_over_budget?(chat)
    end

    Chat.where(id: conversation_ids.uniq).find_each do |chat|
      ConsolidateConversationJob.perform_later(chat)
    end
  end

  private

  def stale_conversations
    Chat
      .where(manual_responses: true)
      .where.not(id: recently_active_chat_ids)
      .joins(:messages)
      .where(never_consolidated.or(has_unconsolidated_messages))
      .distinct
  end

  def over_budget_conversations
    # This is deliberately a broad candidate scan, not a token estimate. Using
    # a four-bytes-per-token conversion here could exclude token-dense or
    # non-ASCII transcripts. The exact Ruby-side token count below decides
    # whether each candidate is actually over budget.
    Chat
      .joins(:messages)
      .where(never_consolidated.or(has_unconsolidated_messages))
      .group("chats.id")
      .having("SUM(OCTET_LENGTH(COALESCE(messages.content, ''))) > ?", ConsolidateConversationJob.transcript_budget_tokens)
  end

  def recently_active_chat_ids
    Message.where(created_at: IDLE_THRESHOLD.ago..).select(:chat_id)
  end

  def never_consolidated
    Chat.arel_table[:last_consolidated_at].eq(nil)
  end

  def has_unconsolidated_messages
    Message.arel_table[:id].gt(Chat.arel_table[:last_consolidated_message_id])
  end

end
