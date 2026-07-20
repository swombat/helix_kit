class ConversationInitiationJob < ApplicationJob

  DAYTIME_HOURS = (9..20).freeze
  ACTIVE_THRESHOLD = 7.days

  def perform
    now = Time.current

    eligible_agents.select { |agent| agent.heartbeat_wake_due_at?(now) }.each do |agent|
      delay = rand(1..20).minutes
      AgentInitiationDecisionJob.set(wait: delay).perform_later(agent, nighttime: nighttime?(now))
    end
  end

  private

  def nighttime?(time)
    !DAYTIME_HOURS.include?(time.in_time_zone("GMT").hour)
  end

  def eligible_agents
    Agent.active
         .unpaused
         .where(runtime: "inline")
         .where(scheduled_wakes_enabled: true)
         .joins(:account)
         .where(accounts: { id: active_account_ids })
         .distinct
  end

  def active_account_ids
    recent_audit = AuditLog.where(created_at: ACTIVE_THRESHOLD.ago..)
                           .where.not(account_id: nil)
                           .select(:account_id)

    recent_message = Message.joins(:chat)
                            .where(created_at: ACTIVE_THRESHOLD.ago..)
                            .where.not(user_id: nil)
                            .select("chats.account_id")

    Account.where(id: recent_audit).or(Account.where(id: recent_message)).select(:id)
  end

end
