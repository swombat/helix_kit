class CleanupOrphanedMessagesJob < ApplicationJob

  def perform
    orphans = Message.where(
      role: "assistant",
      model_id_string: nil,
      output_tokens: nil,
      streaming: false
    )

    count = orphans.count
    if count > 0
      orphans.in_batches(of: 500).destroy_all
      Rails.logger.info "Cleaned up #{count} orphaned assistant messages"
    else
      Rails.logger.info "No orphaned messages found"
    end
  end

end
