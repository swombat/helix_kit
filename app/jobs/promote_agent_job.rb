class PromoteAgentJob < ApplicationJob

  queue_as :default

  def perform(agent_id)
    agent = Agent.find(agent_id)
    return unless agent.migrating?

    volume = Agents::Volume.new(agent)
    volume.ensure!
    volume.seed_from_exporter!
    init_restic_repo!(agent) if Agents::Config.backups_enabled?
    Agents::Sandbox.new(agent).spawn!
    Backup::AgentResticJob.perform_later(agent.id) if Agents::Config.backups_enabled?
  rescue StandardError => e
    agent&.update!(runtime: "inline", migration_started_at: nil) unless agent&.external?
    Rails.logger.error("promotion failed for agent #{agent_id}: #{e.class}: #{e.message}")
    raise
  end

  private

  def init_restic_repo!(agent)
    Backup::AgentResticJob.new.send(:init_restic_repo!, agent)
  end

end
