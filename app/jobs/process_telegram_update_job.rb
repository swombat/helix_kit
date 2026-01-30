class ProcessTelegramUpdateJob < ApplicationJob

  queue_as :default

  def perform(agent, update)
    message = update.dig("message")
    return unless message

    text = message.dig("text")
    return unless text&.start_with?("/start")

    chat_id = message.dig("chat", "id")
    deep_link_param = text.split(" ", 2)[1]

    user = verify_deep_link(agent, deep_link_param)
    return send_unknown_user_message(agent, chat_id) unless user

    subscription = agent.telegram_subscriptions.find_or_initialize_by(user: user)
    subscription.update!(telegram_chat_id: chat_id, blocked: false)

    agent.telegram_send_message(
      chat_id,
      "Connected! You'll receive notifications from <b>#{ERB::Util.html_escape(agent.name)}</b> here."
    )
  end

  private

  def verify_deep_link(agent, param)
    return nil unless param.present?

    user_id = Rails.application.message_verifier(:telegram_deep_link).verified(param)
    return nil unless user_id

    agent.account.users.find_by(id: user_id)
  end

  def send_unknown_user_message(agent, chat_id)
    agent.telegram_send_message(
      chat_id,
      "I couldn't identify your account. Please use the registration link from the app."
    )
  end

end
