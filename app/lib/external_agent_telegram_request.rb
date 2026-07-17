class ExternalAgentTelegramRequest

  TRANSCRIPT_WINDOW = 30

  def initialize(agent:, subscription:, telegram_message:)
    @agent = agent
    @subscription = subscription
    @telegram_message = telegram_message
  end

  def call
    return { status: 503, error: "external runtime unreachable" } if agent.offline?

    endpoint_url = Agents::Endpoint.url_for(agent)
    request = request_text

    AgentRuntimeInteraction.record_trigger!(
      agent: agent,
      chat: nil,
      trigger_kind: "telegram",
      conversation_id: subscription.to_param,
      requested_by: subscription.user.email_address,
      session_id: "#{agent.uuid}-telegram-#{subscription.id}",
      endpoint_url: endpoint_url,
      request_text: request,
      last_included_message_id: telegram_message.id
    ) do
      ChaosTriggerClient.new(endpoint_url, agent.trigger_bearer_token).request_response(
        conversation_id: subscription.to_param,
        requested_by: subscription.user.email_address,
        session_id: "#{agent.uuid}-telegram-#{subscription.id}",
        trigger_kind: "telegram",
        request: request,
        request_delta: request_delta_text,
        persistent_session: agent.persistent_session?,
        provider: Agents::Sandbox.chaos_provider_for(agent),
        model: Agents::Sandbox.chaos_model_for(agent),
        trigger_payload: trigger_payload
      )
    end
  rescue StandardError => e
    Rails.logger.warn "[ExternalAgentTelegramRequest] #{agent.id} trigger failed: #{e.class}: #{e.message}"
    { status: 0, error: e.message }
  end

  private

  attr_reader :agent, :subscription, :telegram_message

  def trigger_payload
    {
      channel: "telegram",
      sender: {
        name: subscription.subscriber_name,
        email: subscription.user.email_address,
        telegram_username: subscription.telegram_username
      },
      text: telegram_message.text,
      thread_id: subscription.to_param,
      history_cursor: telegram_message.to_param
    }
  end

  def request_text
    <<~TEXT
      HelixKit received a Telegram direct message for you.

      Channel: telegram
      Thread ID: #{subscription.to_param}
      History cursor: #{telegram_message.to_param}
      Sender: #{subscription.subscriber_name} <#{subscription.user.email_address}>
      Telegram username: #{subscription.telegram_username.presence || "_unknown_"}
      Message: #{telegram_message.text}

      Telegram is a direct, push-to-phone channel. Decide whether and how to reply in that register.
      Your final Chaos stdout is diagnostic only. To reply, prefer piping the message through stdin:

          printf '%s\n' 'your reply' | helixkit-send-telegram --reply-to #{subscription.to_param}

      You can verify the ground-truth bytes at GET /api/v1/telegram_conversations/#{subscription.to_param}.

      RECENT TELEGRAM TRANSCRIPT FROM DATABASE:
      #{transcript_text}
    TEXT
  end

  def request_delta_text
    <<~TEXT
      New Telegram DM from #{subscription.subscriber_name} (thread #{subscription.to_param}):
      #{telegram_message.text}

      Reply by piping stdin to `helixkit-send-telegram --reply-to #{subscription.to_param}` if appropriate. Stdout is diagnostic only.
      History cursor: #{telegram_message.to_param}
    TEXT
  end

  def transcript_text
    subscription.telegram_messages.chronological.last(TRANSCRIPT_WINDOW).map do |message|
      "#{message.sent_at.iso8601} #{message.sender_name || message.role}: #{message.text}"
    end.join("\n")
  end

end
