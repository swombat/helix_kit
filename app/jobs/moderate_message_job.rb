class ModerateMessageJob < ApplicationJob

  queue_as :default

  retry_on RubyLLM::RateLimitError, wait: :polynomially_longer, attempts: 5
  retry_on RubyLLM::Error, wait: 5.seconds, attempts: 3
  discard_on ActiveRecord::RecordNotFound

  def perform(message)
    return unless message.content.present? && message.moderated_at.nil?

    result = RubyLLM.moderate(message.content, provider: :openai, assume_model_exists: true)
    message.update_columns(moderation_scores: result.category_scores, moderated_at: Time.current)
  end

end
