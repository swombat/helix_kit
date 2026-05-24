module Backup
  class AgentResticJob < ApplicationJob

    queue_as :default

    def perform(agent_id)
      return unless Agents::Config.backups_enabled?

      agent = Agent.find(agent_id)
      return unless agent.external?

      snapshot_id, size, duration_ms, ok, stderr_tail = run_restic_backup(agent)
      AgentBackupSnapshot.create!(
        agent: agent,
        restic_snapshot_id: snapshot_id.presence || "unknown",
        size_bytes: size,
        taken_at: Time.current,
        duration_ms: duration_ms,
        ok: ok,
        stderr_tail: stderr_tail
      )
      prune!(agent) if ok
    end

    private

    def init_restic_repo!(agent)
      cmd = restic_env(agent) + [ "restic/restic:latest", "init" ]
      _out, err, status = Open3.capture3(*docker_run_cmd(agent, *cmd))
      return true if status.success? || err.include?("already initialized")

      raise "restic init failed: #{err}"
    end

    def run_restic_backup(agent)
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      cmd = restic_env(agent) + [ "restic/restic:latest", "backup", "/data", "--tag", "agent_id=#{agent.uuid}", "--tag", "agent_slug=#{agent.name.to_s.parameterize}", "--json" ]
      out, err, status = Open3.capture3(*docker_run_cmd(agent, *cmd))
      duration = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000).round
      parsed = parse_restic_backup(out)
      [ parsed[:snapshot_id], parsed[:total_bytes_processed], duration, status.success?, err.to_s.last(4000) ]
    end

    def prune!(agent)
      cmd = restic_env(agent) + [
        "restic/restic:latest", "forget",
        "--keep-daily", agent.backup_keep_daily.to_s,
        "--keep-weekly", agent.backup_keep_weekly.to_s,
        "--keep-monthly", agent.backup_keep_monthly.to_s,
        "--prune"
      ]
      Open3.capture3(*docker_run_cmd(agent, *cmd))
    end

    def docker_run_cmd(agent, *restic_args)
      [ "docker", "run", "--rm", "-v", "#{Agents::Volume.new(agent).volume_name}:/data:ro", *restic_args ]
    end

    def restic_env(agent)
      [
        "-e", "AWS_ACCESS_KEY_ID=#{ENV['AWS_ACCESS_KEY_ID']}",
        "-e", "AWS_SECRET_ACCESS_KEY=#{ENV['AWS_SECRET_ACCESS_KEY']}",
        "-e", "AWS_DEFAULT_REGION=#{ENV.fetch('AWS_REGION', 'eu-west-1')}",
        "-e", "RESTIC_PASSWORD=#{agent.restic_password}",
        "-e", "RESTIC_REPOSITORY=#{restic_repo_url(agent)}"
      ]
    end

    def restic_repo_url(agent)
      bucket = ENV.fetch("RESTIC_S3_BUCKET")
      "s3:s3.amazonaws.com/#{bucket}/agents/#{agent.uuid}"
    end

    def parse_restic_backup(output)
      result = {}
      output.to_s.each_line do |line|
        json = JSON.parse(line)
        next unless json["message_type"] == "summary"

        result[:snapshot_id] = json["snapshot_id"]
        result[:total_bytes_processed] = json["total_bytes_processed"]
      rescue JSON::ParserError
        next
      end
      result
    end

  end
end
