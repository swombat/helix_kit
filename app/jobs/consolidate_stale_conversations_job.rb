class ConsolidateStaleConversationsJob < ApplicationJob

  # Compatibility shim for scheduler jobs already queued before conversation
  # compaction was retired. Remove after the production queue has drained.
  def perform = nil

end
