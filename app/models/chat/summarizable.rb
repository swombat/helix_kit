module Chat::Summarizable

  extend ActiveSupport::Concern

  SUMMARY_COOLDOWN = 1.hour
  SUMMARY_MAX_WORDS = 200

  def summary_stale?
    summary_generated_at.nil? || summary_generated_at < SUMMARY_COOLDOWN.ago
  end

  def generate_summary!
    return summary unless summary_stale?
    return nil if messages.where(role: %w[user assistant]).count < 2

    new_summary = generate_summary_from_llm
    update!(summary: new_summary, summary_generated_at: Time.current) if new_summary.present?
    summary
  end

  def transcript_for_api
    messages.includes(:user, :agent)
            .where(role: %w[user assistant])
            .order(:created_at)
            .map { |message| format_message_for_api(message) }
  end

  private

  def generate_summary_from_llm
    transcript_lines = messages.where(role: %w[user assistant])
                               .order(:created_at)
                               .limit(20)
                               .map { |message| "#{message.role.titleize}: #{message.content.to_s.truncate(300)}" }

    return nil if transcript_lines.blank?

    prompt = Prompt.new(model: Prompt::LIGHT_MODEL, template: "generate_summary")
    prompt.render(messages: transcript_lines)
    prompt.execute_to_string&.squish&.truncate_words(SUMMARY_MAX_WORDS)
  rescue StandardError => e
    Rails.logger.error "Summary generation failed: #{e.message}"
    nil
  end

  def format_message_for_api(message)
    {
      role: message.role,
      content: message.content,
      author: api_author_name(message),
      timestamp: message.created_at.iso8601
    }
  end

  def api_author_name(message)
    if message.agent.present?
      message.agent.name
    elsif message.user.present?
      message.user.full_name.presence || message.user.email_address.split("@").first
    else
      message.role.titleize
    end
  end

end
