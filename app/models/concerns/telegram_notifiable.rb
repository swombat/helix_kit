module TelegramNotifiable

  extend ActiveSupport::Concern

  class TelegramError < StandardError; end

  included do
    has_many :telegram_subscriptions, dependent: :destroy

    encrypts :telegram_bot_token

    validates :telegram_bot_username, format: { with: /\A[a-zA-Z0-9_]+\z/ }, allow_blank: true

    before_save :set_telegram_webhook_token, if: :telegram_bot_token_changed?
    after_update_commit :manage_telegram_webhook, if: -> { saved_change_to_telegram_bot_token? || saved_change_to_telegram_bot_username? }
  end

  def telegram_configured?
    telegram_bot_token.present? && telegram_bot_username.present?
  end

  def telegram_send_message(chat_id, text, **options)
    body = { chat_id: chat_id, text: text, parse_mode: "HTML" }.merge(options)
    result = telegram_api_request("sendMessage", body)

    raise TelegramError, result["description"] unless result["ok"]

    result
  end

  def set_telegram_webhook!
    return unless telegram_configured?

    webhook_url = "#{Rails.application.credentials.dig(:app, :url)}/telegram/webhook/#{telegram_webhook_token}"
    result = telegram_api_request("setWebhook", {
      url: webhook_url,
      allowed_updates: [ "message" ],
      secret_token: telegram_webhook_secret
    })

    Rails.logger.error("[Telegram] setWebhook failed for agent #{id}: #{result['description']}") unless result["ok"]
  end

  def telegram_webhook_info
    return nil unless telegram_bot_token.present?
    telegram_api_request("getWebhookInfo", {})
  end

  def delete_telegram_webhook!
    return unless telegram_bot_token.present?

    result = telegram_api_request("deleteWebhook", { drop_pending_updates: true })

    Rails.logger.error("[Telegram] deleteWebhook failed for agent #{id}: #{result['description']}") unless result["ok"]
  end

  def telegram_webhook_secret
    Base64.urlsafe_encode64(
      Rails.application.key_generator.generate_key("telegram_webhook_secret:#{id}", 32),
      padding: false
    )
  end

  def notify_subscribers!(message, chat)
    return unless telegram_configured?

    telegram_subscriptions.active.each do |subscription|
      TelegramNotificationJob.perform_later(subscription, message, chat)
    end
  end

  def telegram_deep_link_for(user)
    # Telegram deep link params only allow [A-Za-z0-9_] and max 64 chars,
    # so we store a short random token in Rails cache instead of signing
    token = SecureRandom.alphanumeric(32)
    Rails.cache.write("telegram_deep_link:#{token}", { user_id: user.id, agent_id: id }, expires_in: 7.days)
    "https://t.me/#{telegram_bot_username}?start=#{token}"
  end

  private

  def telegram_api_request(method, body)
    uri = URI("https://api.telegram.org/bot#{telegram_bot_token}/#{method}")
    response = Net::HTTP.post(uri, body.to_json, "Content-Type" => "application/json")
    JSON.parse(response.body)
  end

  def set_telegram_webhook_token
    if telegram_bot_token.present?
      self.telegram_webhook_token ||= SecureRandom.hex(16)
    else
      self.telegram_webhook_token = nil
    end
  end

  def manage_telegram_webhook
    ManageTelegramWebhookJob.perform_later(self)
  end

end
