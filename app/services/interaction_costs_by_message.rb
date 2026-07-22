class InteractionCostsByMessage

  POSTING_GRACE_PERIOD = 30.seconds

  def initialize(chat:, messages:)
    @chat = chat
    @messages = messages.to_a
  end

  def call
    linked_interactions.filter_map do |message_id, interaction|
      cost = interaction.estimated_cost
      next unless cost[:amount_usd]

      [ message_id, cost ]
    end.to_h
  end

  def linked_interactions
    displayed_messages = messages.select { |message| message.role == "assistant" && message.agent_id.present? }
    return {} if displayed_messages.empty?

    interactions = relevant_interactions(displayed_messages)
    return {} if interactions.empty?

    candidate_messages = candidate_messages_for(interactions)
    displayed_ids = displayed_messages.index_by(&:id)

    claims = interactions.filter_map do |interaction|
      candidates = candidate_messages.select do |message|
        message.agent_id == interaction.agent_id &&
          message.created_at.between?(interaction.started_at, interaction.finished_at + POSTING_GRACE_PERIOD) &&
          (interaction.chat_id.nil? || message.chat_id == interaction.chat_id)
      end
      next unless candidates.one?

      [ candidates.first.id, interaction ]
    end

    claims
      .group_by(&:first)
      .filter_map do |message_id, message_claims|
        next unless displayed_ids.key?(message_id) && message_claims.one?

        [ message_id, message_claims.first.last ]
      end
      .to_h
  end

  private

  attr_reader :chat, :messages

  def relevant_interactions(displayed_messages)
    interactions = AgentRuntimeInteraction.where(agent_id: displayed_messages.map(&:agent_id).uniq)
    interactions = interactions
      .where(chat_id: chat.id, trigger_kind: "conversation")
      .or(interactions.where(chat_id: nil, trigger_kind: "wake"))

    interactions
      .where.not(finished_at: nil)
      .where("started_at <= ?", displayed_messages.map(&:created_at).max)
      .where("finished_at >= ?", displayed_messages.map(&:created_at).min - POSTING_GRACE_PERIOD)
      .order(:started_at, :id)
      .to_a
  end

  def candidate_messages_for(interactions)
    Message.joins(:chat)
      .where(chats: { account_id: chat.account_id })
      .where(role: "assistant", agent_id: interactions.map(&:agent_id).uniq)
      .where(
        created_at: interactions.map(&:started_at).min..(
          interactions.map(&:finished_at).max + POSTING_GRACE_PERIOD
        )
      )
      .order(:created_at, :id)
      .to_a
  end

end
