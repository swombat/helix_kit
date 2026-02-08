class FixHallucinatedToolCallsJob < ApplicationJob

  queue_as :default

  discard_on ActiveRecord::RecordNotFound

  def perform(message)
    return unless message.fixable

    Rails.logger.info "🔧 Auto-fixing hallucinated tool calls for message #{message.id}"
    message.fix_hallucinated_tool_calls!
    Rails.logger.info "🔧 Successfully fixed hallucinated tool calls for message #{message.id}"
  rescue => e
    Rails.logger.error "🔧 Failed to auto-fix hallucinated tool calls for message #{message.id}: #{e.message}"
  end

end
