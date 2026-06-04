module Api
  module V1
    class TelegramMessagesController < BaseController

      MAX_MESSAGE_LENGTH = 4_000

      def create
        return render json: { error: "Telegram messaging is only available to agent API keys" }, status: :forbidden unless current_api_agent
        return render json: { error: "Telegram is not configured for this agent" }, status: :unprocessable_entity unless current_api_agent.telegram_configured?

        text = params[:text].to_s.strip
        return render json: { error: "text is required" }, status: :unprocessable_entity if text.blank?
        return render json: { error: "text is too long (max #{MAX_MESSAGE_LENGTH} characters)" }, status: :unprocessable_entity if text.length > MAX_MESSAGE_LENGTH

        subscriptions = target_subscriptions
        return render json: { error: "No matching active Telegram subscribers for this agent" }, status: :not_found if subscriptions.empty?

        delivered = []
        blocked = []
        failures = []

        subscriptions.each do |subscription|
          begin
            current_api_agent.telegram_send_message(subscription.telegram_chat_id, ERB::Util.html_escape(text))
            delivered << subscriber_json(subscription)
          rescue TelegramNotifiable::TelegramError => e
            if e.message.include?("blocked") || e.message.include?("chat not found")
              subscription.mark_blocked!
              blocked << subscriber_json(subscription)
            else
              failures << subscriber_json(subscription).merge(error: e.message)
            end
          end
        end

        status = failures.any? ? :bad_gateway : :created
        render json: { delivered: delivered, blocked: blocked, failures: failures }, status: status
      end

      private

      def target_subscriptions
        scope = current_api_agent.telegram_subscriptions.active.includes(user: :profile)
        target = params[:recipient].presence || params[:to].presence
        needle = target.to_s.downcase.strip
        return scope.to_a if needle.blank? || needle == "all"

        scope.select do |subscription|
          user = subscription.user
          candidates = [
            user.email_address,
            user.first_name,
            user.last_name,
            user.full_name,
            user.profile&.first_name,
            user.profile&.last_name,
            user.profile&.full_name
          ].compact.map { |value| value.to_s.downcase }
          candidates.any? { |value| value.include?(needle) }
        end
      end

      def subscriber_json(subscription)
        user = subscription.user
        {
          user_id: user.to_param,
          name: user.full_name.presence || user.email_address,
          email: user.email_address
        }
      end

    end
  end
end
