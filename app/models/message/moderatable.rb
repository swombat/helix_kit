module Message::Moderatable

  extend ActiveSupport::Concern

  MODERATION_THRESHOLD = 0.5

  included do
    after_commit :queue_moderation, on: :create, if: :user_message_with_content?
  end

  def moderation_flagged?
    moderation_scores&.values&.any? { |score| score.to_f >= MODERATION_THRESHOLD }
  end

  alias_method :moderation_flagged, :moderation_flagged?

  def moderation_severity
    return unless moderation_flagged?
    moderation_scores.values.max.to_f >= 0.8 ? :high : :medium
  end

  private

  def user_message_with_content?
    role == "user" && content.present?
  end

  def queue_moderation
    ModerateMessageJob.perform_later(self)
  end

end
