class TelegramWebhooksController < ApplicationController

  skip_before_action :verify_authenticity_token
  skip_before_action :require_authentication

  def receive
    agent = Agent.find_by(telegram_webhook_token: params[:token])
    return head(:not_found) unless agent

    return head(:unauthorized) unless valid_secret?(agent)

    update = JSON.parse(request.raw_post)
    ProcessTelegramUpdateJob.perform_later(agent, update)

    head :ok
  rescue JSON::ParserError
    head :bad_request
  end

  private

  def valid_secret?(agent)
    provided = request.headers["X-Telegram-Bot-Api-Secret-Token"].to_s
    ActiveSupport::SecurityUtils.secure_compare(provided, agent.telegram_webhook_secret)
  end

end
