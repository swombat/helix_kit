class ConsolidateStaleConversationsJob < ApplicationJob

  IDLE_THRESHOLD = 6.hours

  def perform
    stale_conversations.find_each do |chat|
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
