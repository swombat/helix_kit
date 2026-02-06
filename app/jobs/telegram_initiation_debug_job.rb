class TelegramInitiationDebugJob < ApplicationJob

  queue_as :default

  def perform(agent, reason)
    return unless agent.telegram_configured?

    text = <<~HTML.strip
      <b>[Debug] #{ERB::Util.html_escape(agent.name)}</b> chose not to act

      #{ERB::Util.html_escape(reason.to_s.truncate(500))}
    HTML

    agent.telegram_subscriptions.active.each do |subscription|
      agent.telegram_send_message(subscription.telegram_chat_id, text)
    rescue TelegramNotifiable::TelegramError => e
      subscription.mark_blocked! if e.message.include?("blocked") || e.message.include?("chat not found")
    end
  end

end
