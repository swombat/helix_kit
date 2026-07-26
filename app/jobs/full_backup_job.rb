class FullBackupJob < ApplicationJob

  queue_as :default

  # fail_fast: true  — manual/interactive runs (db_backup:perform): any agent
  #                    failure aborts the run so the database dump is never
  #                    created over a knowingly incomplete agent backup set.
  # fail_fast: false — scheduled nightly runs: agent failures are recorded
  #                    (AgentBackupSnapshot ok: false) and logged, remaining
  #                    agents are still backed up, and the database dump always
  #                    runs. Restore is unaffected: it only ever uses the latest
  #                    *successful* snapshot recorded in the dump.
  def perform(fail_fast: false)
    Agent.externally_hosted.where.not(uuid: nil).find_each do |agent|
      backup_agent!(agent, fail_fast)
    end

    DatabaseBackupJob.perform_now
  end

  private

  def backup_agent!(agent, fail_fast)
    Backup::AgentResticJob.perform_now(agent.id, force: fail_fast)
  rescue StandardError => e
    raise if fail_fast

    Rails.logger.error "Agent backup failed for #{agent.name}: #{e.class} - #{e.message}"
  end

end
