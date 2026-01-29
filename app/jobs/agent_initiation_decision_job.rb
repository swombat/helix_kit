class AgentInitiationDecisionJob < ApplicationJob

  queue_as :default

  retry_on RubyLLM::ServerError, wait: :polynomially_longer, attempts: 3
  retry_on RubyLLM::RateLimitError, wait: :polynomially_longer, attempts: 5

  ACTIVE_THRESHOLD = 7.days

  def perform(agent)
    if agent.at_initiation_cap?
      audit(agent, { action: "skipped", reason: "at_hard_cap" })
      return
    end

    decision = get_decision(agent)
    execute_decision(agent, decision)
    audit(agent, decision)
  rescue => e
    Rails.logger.error "[ConversationInitiation] Agent #{agent.id} failed: #{e.message}"
  end

  private

  def get_decision(agent)
    prompt = agent.build_initiation_prompt(
      conversations: agent.continuable_conversations,
      recent_initiations: recent_initiations_for(agent.account),
      human_activity: human_activity_for(agent.account)
    )

    response = RubyLLM.chat(
      model: agent.model_id,
      provider: :openrouter,
      assume_model_exists: true
    ).ask(prompt)

    parse_decision_response(response.content)
  end

  def parse_decision_response(content)
    JSON.parse(content).symbolize_keys
  rescue JSON::ParserError
    extract_json_from_prose(content)
  end

  def extract_json_from_prose(content)
    json_match = content.match(/\{[^{}]*(?:\{[^{}]*\}[^{}]*)*\}/m)

    if json_match
      JSON.parse(json_match[0]).symbolize_keys
    else
      Rails.logger.warn "[ConversationInitiation] Could not extract JSON from response: #{content.truncate(200)}"
      { action: "nothing", reason: "Could not extract decision from response", raw_response: content.truncate(1000) }
    end
  rescue JSON::ParserError => e
    Rails.logger.warn "[ConversationInitiation] Extracted text was not valid JSON: #{e.message}"
    { action: "nothing", reason: "Could not parse extracted JSON", raw_response: content.truncate(1000) }
  end

  def recent_initiations_for(account)
    account.chats.initiated
           .where(created_at: Agent::RECENTLY_INITIATED_WINDOW.ago..)
           .includes(:initiated_by_agent)
  end

  def human_activity_for(account)
    user_ids_with_activity = Message.joins(:chat)
                                    .where(chats: { account_id: account.id })
                                    .where(created_at: ACTIVE_THRESHOLD.ago..)
                                    .where.not(user_id: nil)
                                    .group(:user_id)
                                    .maximum(:created_at)

    users_by_id = User.where(id: user_ids_with_activity.keys).index_by(&:id)

    user_ids_with_activity.filter_map do |user_id, last_at|
      [ users_by_id[user_id], last_at ] if users_by_id[user_id]
    end
  end

  def execute_decision(agent, decision)
    case decision[:action]
    when "continue"
      chat = agent.account.chats.find_by(id: Chat.decode_id(decision[:conversation_id]))
      ManualAgentResponseJob.perform_later(chat, agent, initiation_reason: decision[:reason]) if chat&.respondable?
    when "initiate"
      Chat.initiate_by_agent!(
        agent,
        topic: decision[:topic],
        message: decision[:message],
        reason: decision[:reason]
      )
    end
  end

  def audit(agent, decision)
    AuditLog.create!(
      account: agent.account,
      action: "agent_initiation_#{decision[:action]}",
      auditable: agent,
      data: decision.slice(:topic, :reason, :conversation_id, :raw_response)
    )
  end

end
