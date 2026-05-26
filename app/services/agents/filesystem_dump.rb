module Agents
  class FilesystemDump
    require "shellwords"

    MAX_ENTRIES = 120
    MAX_DEPTH = 6
    MAX_FILE_BYTES = 4_000
    IDENTITY_ROOT = "/home/agent/identity"
    CONTAINER_HOME_ROOT = "/home/agent"
    EXCLUDED_CONTAINER_PATHS = %w[
      ./.chaos
      ./.chaos/*
    ].freeze
    PREVIEWABLE_EXTENSIONS = %w[
      .md .txt .json .yml .yaml .toml .env .gitignore .rb .js .ts .svelte .py .sh
    ].freeze

    attr_reader :agent, :target

    def initialize(agent, target: :identity)
      @agent = agent
      @target = target.to_sym
    end

    def as_json
      return unavailable("agent uuid missing") if agent.uuid.blank?
      return unavailable("Docker daemon is not reachable") unless docker_ok?
      return unavailable("identity volume is missing") if identity? && !volume_exists?
      return unavailable("container is not configured") if container_home? && agent.container_name.blank?
      return unavailable("container is not running") if container_home? && !container_running?

      entries = list_entries.first(MAX_ENTRIES).map { |entry| entry_json(entry) }

      {
        root: root,
        volume_name: volume.volume_name,
        container_name: agent.container_name,
        target: target,
        truncated: list_entries.length > MAX_ENTRIES,
        entries: entries
      }
    rescue StandardError => e
      unavailable("#{e.class}: #{e.message}")
    end

    private

    def unavailable(error)
      {
        root: root,
        volume_name: agent.uuid.present? ? volume.volume_name : nil,
        container_name: agent.container_name,
        target: target,
        error: error,
        entries: []
      }
    end

    def docker_ok?
      docker_capture("info", "--format", "{{.ServerVersion}}")[:ok]
    end

    def volume_exists?
      docker_capture("volume", "inspect", volume.volume_name)[:ok]
    end

    def container_running?
      result = docker_capture("container", "inspect", "--format", "{{.State.Running}}", agent.container_name)
      result[:ok] && result[:stdout].strip == "true"
    end

    def list_entries
      @list_entries ||= begin
        result = find_entries
        return [] unless result[:ok]

        result[:stdout]
          .lines
          .map(&:strip)
          .reject { |path| path.blank? || path == "." }
          .sort
      end
    end

    def entry_json(relative_path)
      type = directory?(relative_path) ? "directory" : "file"
      json = {
        path: relative_path.delete_prefix("./"),
        name: File.basename(relative_path),
        type: type,
        depth: relative_path.delete_prefix("./").count("/")
      }

      return json if type == "directory"

      json.merge!(size_bytes: file_size(relative_path))
      json.merge!(file_preview(relative_path))
      json
    end

    def directory?(relative_path)
      docker_run("test", "-d", relative_path)[:ok]
    end

    def file_size(relative_path)
      result = docker_run("wc", "-c", relative_path)
      return nil unless result[:ok]

      result[:stdout].to_s.split.first.to_i
    end

    def file_preview(relative_path)
      return { previewable: false, skip_reason: "unsupported file type" } unless previewable_path?(relative_path)

      result = docker_run("head", "-c", MAX_FILE_BYTES.to_s, relative_path)
      return { previewable: false, skip_reason: "could not read file" } unless result[:ok]

      content = result[:stdout].to_s
      return { previewable: false, skip_reason: "binary-looking content" } if content.include?("\u0000")

      size = file_size(relative_path)
      {
        previewable: true,
        content: content,
        truncated: size.present? && size > MAX_FILE_BYTES
      }
    end

    def previewable_path?(relative_path)
      extension = File.extname(relative_path)
      PREVIEWABLE_EXTENSIONS.include?(extension) || extension.blank?
    end

    def docker_run(*command)
      return container_home_run(*command) if container_home?

      docker_capture(
        "run", "--rm",
        "-v", "#{volume.volume_name}:/identity:ro",
        "-w", "/identity",
        "busybox",
        *command
      )
    end

    def find_entries
      return container_home_find if container_home?

      docker_run("find", ".", "-maxdepth", MAX_DEPTH.to_s, "-print")
    end

    def container_home_find
      docker_capture(
        "exec",
        agent.container_name,
        "sh",
        "-c",
        "cd /home/agent && find . -maxdepth #{MAX_DEPTH} \\( -path './.chaos' -o -path './.chaos/*' \\) -prune -o -print"
      )
    end

    def container_home_run(*command)
      escaped_command = command.map { |part| Shellwords.escape(part.to_s) }.join(" ")
      docker_capture(
        "exec",
        agent.container_name,
        "sh",
        "-c",
        "cd /home/agent && #{escaped_command}"
      )
    end

    def docker_capture(*args)
      stdout, stderr, status = Open3.capture3("docker", *args)
      { stdout: stdout, stderr: stderr, ok: status.success? }
    end

    def volume
      @volume ||= Agents::Volume.new(agent)
    end

    def identity?
      target == :identity
    end

    def container_home?
      target == :container_home
    end

    def root
      container_home? ? CONTAINER_HOME_ROOT : IDENTITY_ROOT
    end

  end
end
