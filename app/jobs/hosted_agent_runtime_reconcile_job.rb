class HostedAgentRuntimeReconcileJob < ApplicationJob

  queue_as :default

  retry_on Agents::Sandbox::SandboxError, wait: 5.minutes, attempts: 3

  def perform(agent_id = nil)
    scope = agent_id.present? ? Agent.where(id: agent_id) : Agent.externally_hosted

    scope.find_each do |agent|
      reconcile_agent(agent, raise_on_error: agent_id.present?)
    end
  end

  private

  def reconcile_agent(agent, raise_on_error:)
    return unless agent.externally_hosted?

    sandbox = Agents::Sandbox.new(agent)
    return unless sandbox.stale_image?

    if sandbox.active_turn?
      self.class.set(wait: 5.minutes).perform_later(agent.id)
      Rails.logger.info("hosted agent runtime reconcile skipped active agent #{agent.id}; retry queued")
      return
    end

    sandbox.recreate!
    Rails.logger.info("hosted agent runtime reconcile recreated sandbox for agent #{agent.id}")
  rescue StandardError => e
    agent.update!(
      sandbox_last_error: "#{e.class}: #{e.message}",
      sandbox_last_error_at: Time.current,
      health_state: "unhealthy"
    )
    Rails.logger.error("hosted agent runtime reconcile failed for agent #{agent.id}: #{e.class}: #{e.message}")
    raise if raise_on_error
  end

end
