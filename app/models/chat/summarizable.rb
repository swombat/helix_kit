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

  def transcript_for_api(after_message_id: nil, since: nil)
    scope = messages.includes(:user, :agent, attachments_attachments: :blob)
                     .where(role: %w[user assistant])
                     .order(:created_at)
    scope = scope.where("messages.id > ?", after_message_id) if after_message_id.present?
    since_time = parse_since(since)
    scope = scope.where("messages.created_at > ?", since_time) if since_time

    scope.map { |message| format_message_for_api(message) }
  end

  private

  def parse_since(value)
    return nil if value.blank?
    Time.iso8601(value.to_s)
  rescue ArgumentError
    nil
  end

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
      id: message.to_param,
      role: message.role,
      content: message.content,
      author: api_author_name(message),
      timestamp: message.created_at.iso8601,
      attachments: message.attachments_for_api
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
