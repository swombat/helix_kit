class PromoteAgentJob < ApplicationJob

  queue_as :default

  def perform(agent_id)
    agent = Agent.find(agent_id)
    return unless agent.migrating? || agent.provisioning?

    volume = Agents::Volume.new(agent)
    volume.ensure!
    if volume.empty?
      volume.seed_from_exporter!
    end
    agent.update!(identity_seeded_at: Time.current) if agent.born_hosted? && agent.identity_seeded_at.blank?
    init_restic_repo!(agent) if Agents::Config.backups_enabled?
    Agents::Sandbox.new(agent).spawn!
    if agent.born_hosted?
      agent.update!(runtime_ready_at: Time.current)
      OrientNewAgentJob.perform_later(agent.id)
    end
    Backup::AgentResticJob.perform_later(agent.id) if Agents::Config.backups_enabled?
  rescue StandardError => e
    if agent&.born_hosted?
      agent.update!(
        runtime: "provisioning",
        health_state: "unhealthy",
        sandbox_last_error: "#{e.class}: #{e.message}",
        sandbox_last_error_at: Time.current
      )
    elsif !agent&.external?
      agent&.update!(
        runtime: "inline",
        migration_started_at: nil,
        health_state: "unhealthy",
        sandbox_last_error: "#{e.class}: #{e.message}",
        sandbox_last_error_at: Time.current
      )
    end
    Rails.logger.error("promotion failed for agent #{agent_id}: #{e.class}: #{e.message}")
    raise
  end

  private

  def init_restic_repo!(agent)
    Backup::AgentResticJob.new.send(:init_restic_repo!, agent)
  end

end
