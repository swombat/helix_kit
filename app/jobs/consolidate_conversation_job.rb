class ConsolidateConversationJob < ApplicationJob

  # Compatibility shim for jobs already queued before conversation compaction
  # was retired. Remove after the production queue has drained.
  def perform(*) = nil

end
