class ProcessTelegramUpdateJob < ApplicationJob

  queue_as :default

  def perform(agent, update)
    message = update.dig("message")
    return unless message
    return if message.dig("chat", "type").present? && message.dig("chat", "type") != "private"

    text = message.dig("text")
    return if text.blank?

    chat_id = message.dig("chat", "id")
    return process_start(agent, message, text, chat_id) if text.start_with?("/start")

    process_direct_message(agent, message, text, chat_id)
  end

  private

  def process_start(agent, message, text, chat_id)
    deep_link_param = text.split(" ", 2)[1]

    user = verify_deep_link(agent, deep_link_param)
    return send_unknown_user_message(agent, chat_id) unless user

    subscription = agent.telegram_subscriptions.find_or_initialize_by(user: user)
    subscription.update!(
      telegram_chat_id: chat_id,
      telegram_username: message.dig("from", "username"),
      blocked: false
    )

    agent.telegram_send_message(
      chat_id,
      "Connected! You'll receive notifications from <b>#{ERB::Util.html_escape(agent.name)}</b> here."
    )
  end

  def process_direct_message(agent, message, text, chat_id)
    subscription = agent.telegram_subscriptions.find_by(telegram_chat_id: chat_id)
    return unless subscription

    subscription.update!(
      telegram_username: message.dig("from", "username"),
      blocked: false
    )

    telegram_message = create_inbound_message(subscription, message, text)
    return unless telegram_message
    return unless agent.active? && !agent.paused? && agent.external? && agent.trigger_bearer_token.present?

    TelegramAgentTriggerJob.perform_later(subscription, telegram_message)
  end

  def create_inbound_message(subscription, message, text)
    telegram_message_id = message["message_id"]
    existing = subscription.telegram_messages.find_by(telegram_message_id: telegram_message_id) if telegram_message_id
    return if existing

    subscription.telegram_messages.create!(
      role: "user",
      text: text,
      sender_name: subscription.subscriber_name,
      sender_username: message.dig("from", "username"),
      telegram_message_id: telegram_message_id,
      sent_at: message["date"] ? Time.zone.at(message["date"]) : Time.current
    )
  rescue ActiveRecord::RecordNotUnique
    nil
  end

  def verify_deep_link(agent, param)
    return nil unless param.present?

    data = Rails.cache.read("telegram_deep_link:#{param}")
    return nil unless data && data[:agent_id] == agent.id

    agent.account.users.find_by(id: data[:user_id])
  end

  def send_unknown_user_message(agent, chat_id)
    agent.telegram_send_message(
      chat_id,
      "I couldn't identify your account. Please use the registration link from the app."
    )
  end

end
