class TelegramNotificationJob < ApplicationJob

  queue_as :default

  retry_on TelegramNotifiable::TelegramError, wait: 30.seconds, attempts: 2

  def perform(subscription, message, chat)
    return if subscription.blocked?

    agent = subscription.agent
    return unless agent.telegram_configured?

    preview = message.content.to_s.truncate(300)
    chat_url = "#{Rails.application.credentials.dig(:app, :url)}/accounts/#{chat.account_id}/chats/#{chat.to_param}"

    text = <<~HTML.strip
      <b>#{ERB::Util.html_escape(agent.name)}</b> in "#{ERB::Util.html_escape(chat.title_or_default)}"

      #{ERB::Util.html_escape(preview)}
    HTML

    agent.telegram_send_message(
      subscription.telegram_chat_id,
      text,
      reply_markup: {
        inline_keyboard: [ [ { text: "Open Conversation", url: chat_url } ] ]
      }
    )
  rescue TelegramNotifiable::TelegramError => e
    if e.message.include?("blocked") || e.message.include?("chat not found")
      subscription.mark_blocked!
    else
      raise
    end
  end

end
