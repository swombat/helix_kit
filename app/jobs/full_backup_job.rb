class FullBackupJob < ApplicationJob

  queue_as :default

  def perform
    Agent.externally_hosted.where.not(uuid: nil).find_each do |agent|
      Backup::AgentResticJob.perform_now(agent.id, force: true)
    end

    DatabaseBackupJob.perform_now
  end

end
