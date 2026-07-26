module Backup
  class AgentResticRestore

    class RestoreError < StandardError; end

    def self.restore_all!
      Agent.externally_hosted.where.not(uuid: nil).find_each do |agent|
        new(agent).restore!
      end
    end

    def initialize(agent)
      @agent = agent
    end

    def restore!
      snapshot = agent.agent_backup_snapshots.where(ok: true).order(taken_at: :desc).first
      raise RestoreError, "No successful agent backup is recorded for #{agent.name}" unless snapshot

      puts "Restoring Chaos agent #{agent.name} (#{agent.uuid}) from #{snapshot.restic_snapshot_id}..."
      remove_container!
      recreate_volumes!
      restore_snapshot!(snapshot.restic_snapshot_id)
      configure_for_local_runtime!
      Agents::Sandbox.new(agent).spawn! if agent.external?
      puts "Restored Chaos agent #{agent.name}."
    end

    private

    attr_reader :agent

    def remove_container!
      return if agent.container_name.blank?

      system("docker", "rm", "-f", agent.container_name, out: File::NULL, err: File::NULL)
    end

    def recreate_volumes!
      Agents::VolumeSet.new(agent).each do |_name, volume|
        system("docker", "volume", "rm", "-f", volume, out: File::NULL, err: File::NULL)
        success = system("docker", "volume", "create", volume, out: File::NULL, err: File::NULL)
        raise RestoreError, "Could not create Docker volume #{volume}" unless success
      end
    end

    def restore_snapshot!(snapshot_id)
      command = [
        "docker", "run", "--rm",
        *Backup::AgentRestic.restore_mounts(agent),
        *Backup::AgentRestic.docker_environment(agent),
        "restic/restic:latest",
        "restore", snapshot_id,
        "--target", "/restore"
      ]
      success = system(*command)
      raise RestoreError, "Restic restore failed for #{agent.name}" unless success
    end

    def configure_for_local_runtime!
      agent.update!(
        container_image: Agents::Config.default_image,
        sandbox_host: Agents::Config.sandbox_host,
        endpoint_url: nil,
        health_state: "unknown",
        consecutive_health_failures: 0,
        sandbox_last_error: nil,
        sandbox_last_error_at: nil
      )
    end

  end
end
