require "shellwords"

module Agents
  class Sandbox

    class SandboxError < StandardError; end

    REPO_PATH = "/home/agent/repo"

    attr_reader :agent

    def initialize(agent)
      @agent = agent
    end

    def spawn!
      raise SandboxError, "agent uuid missing" if agent.uuid.blank?
      raise SandboxError, "container_name missing" if agent.container_name.blank?
      raise SandboxError, "container_image missing" if agent.container_image.blank?
      raise SandboxError, "outbound_api_token missing" if agent.outbound_api_token.blank?
      raise SandboxError, "trigger_bearer_token missing" if agent.trigger_bearer_token.blank?

      Agents::Network.ensure!
      Agents::Volume.new(agent).ensure!

      if container_exists?
        if container_image_current?
          start!
        else
          migrate_repo_volume_from_container!
          remove_container!
          run_container!
        end
      else
        run_container!
      end

      refresh_dev_endpoint! if Agents::Config.publish_ports?
      wait_for_health!
      agent.update!(runtime: "external", health_state: "healthy", consecutive_health_failures: 0)
    end

    def stale_image?
      container_exists? && !container_image_current?
    end

    def active_turn?
      return false unless container_exists?

      result = docker_capture("exec", agent.container_name, "pgrep", "-f", "chaos exec")
      result[:ok]
    rescue StandardError
      false
    end

    def recreate!
      migrate_repo_volume_from_container! if container_exists?
      remove!(delete_volume: false)
      spawn!
    end


    def status
      @configuration_error = nil
      base = {
        configured: agent.container_name.present?,
        container_name: agent.container_name,
        image: agent.container_image,
        endpoint_url: agent.endpoint_url,
        configured_helixkit_app_url: safe_config_value(:internal_url),
        volume_name: agent.uuid.present? ? Agents::Volume.new(agent).volume_name : nil,
        chaos_volume_name: agent.uuid.present? ? "chaos-home-#{agent.uuid}" : nil,
        repo_volume_name: agent.uuid.present? ? repo_volume_name : nil,
        docker_available: false,
        container_exists: false,
        identity_volume_exists: false,
        chaos_volume_exists: false,
        repo_volume_exists: false
      }
      base[:configuration_error] = @configuration_error if @configuration_error.present?

      docker_info = docker_capture("info", "--format", "{{.ServerVersion}}")
      unless docker_info[:ok]
        return base.merge(
          docker_error: docker_info[:stderr].presence || docker_info[:stdout].presence || "Docker daemon is not reachable"
        )
      end

      base[:docker_available] = true
      base[:docker_version] = docker_info[:stdout].strip
      base[:identity_volume_exists] = volume_exists?(base[:volume_name])
      base[:chaos_volume_exists] = volume_exists?(base[:chaos_volume_name])
      base[:repo_volume_exists] = volume_exists?(base[:repo_volume_name])
      base[:image_present] = image_present?(agent.container_image)

      if agent.container_name.present?
        inspect = docker_capture("container", "inspect", agent.container_name)
        if inspect[:ok]
          container = JSON.parse(inspect[:stdout]).first
          state = container.fetch("State", {})
          network = container.fetch("NetworkSettings", {})
          configured_image_id = image_id(agent.container_image)
          container_image_current = configured_image_id.present? && container["Image"] == configured_image_id
          base.merge!(
            container_exists: true,
            container_id: container["Id"].to_s.first(12),
            container_image_id: container["Image"],
            configured_image_id: configured_image_id,
            container_image_current: container_image_current,
            image_stale: !container_image_current,
            container_helixkit_app_url: container_env_value(container, "HELIXKIT_APP_URL"),
            container_state: state["Status"],
            container_running: state["Running"],
            container_exit_code: state["ExitCode"],
            container_error: state["Error"],
            container_started_at: state["StartedAt"],
            container_finished_at: state["FinishedAt"],
            published_ports: network["Ports"]
          )
          base[:log_tail] = logs_tail if base[:container_exists]
        else
          base[:container_error] = inspect[:stderr]
        end
      end

      base
    rescue StandardError => e
      (defined?(base) && base ? base : fallback_status).merge(docker_error: "#{e.class}: #{e.message}")
    end

    def stop!
      system("docker", "stop", agent.container_name, out: File::NULL, err: File::NULL)
    end

    def start!
      system("docker", "start", agent.container_name, out: File::NULL, err: File::NULL) || raise(SandboxError, "failed to start #{agent.container_name}")
    end

    def remove!(delete_volume: false)
      remove_container!
      if delete_volume
        Agents::Volume.new(agent).destroy!
        destroy_repo_volume!
      end
    end

    def healthy?
      uri = URI("#{Agents::Endpoint.url_for(agent)}/health")
      Net::HTTP.get_response(uri).code == "200"
    rescue StandardError
      false
    end

    private


    def docker_capture(*args)
      stdout, stderr, status = Open3.capture3("docker", *args)
      { stdout: stdout, stderr: stderr, ok: status.success? }
    end

    def safe_config_value(name)
      Agents::Config.public_send(name)
    rescue KeyError => e
      @configuration_error = "#{e.class}: #{e.message}"
      nil
    end

    def fallback_status
      {
        configured: agent.container_name.present?,
        container_name: agent.container_name,
        image: agent.container_image,
        endpoint_url: agent.endpoint_url,
        configured_helixkit_app_url: nil,
        volume_name: nil,
        chaos_volume_name: nil,
        repo_volume_name: nil,
        docker_available: false,
        container_exists: false,
        identity_volume_exists: false,
        chaos_volume_exists: false,
        repo_volume_exists: false
      }
    end

    def volume_exists?(name)
      return false if name.blank?
      docker_capture("volume", "inspect", name)[:ok]
    end

    def image_present?(image)
      image_id(image).present?
    end

    def image_id(image)
      return nil if image.blank?
      result = docker_capture("image", "inspect", "--format", "{{.Id}}", image)
      result[:ok] ? result[:stdout].strip.presence : nil
    end

    def image_current?(container_image_id, configured_image)
      configured_image_id = image_id(configured_image)
      configured_image_id.present? && container_image_id == configured_image_id
    end

    def container_env_value(container, name)
      Array(container.dig("Config", "Env")).find { |entry| entry.start_with?("#{name}=") }&.split("=", 2)&.last
    end

    def logs_tail
      result = docker_capture("logs", "--tail", "30", agent.container_name)
      [ result[:stdout], result[:stderr] ].compact.join("
").strip.presence
    end

    def container_exists?
      system("docker", "container", "inspect", agent.container_name, out: File::NULL, err: File::NULL)
    end

    def container_image_current?
      inspect = docker_capture("container", "inspect", agent.container_name)
      return false unless inspect[:ok]

      container = JSON.parse(inspect[:stdout]).first
      image_current?(container["Image"], agent.container_image)
    rescue StandardError
      false
    end

    def remove_container!
      system("docker", "rm", "-f", agent.container_name, out: File::NULL, err: File::NULL)
    end

    def repo_volume_name
      "hk-agent-#{agent.uuid}-repo"
    end

    def ensure_repo_volume!
      return true if volume_exists?(repo_volume_name)

      system("docker", "volume", "create", repo_volume_name, out: File::NULL, err: File::NULL) || raise(SandboxError, "failed to create docker volume #{repo_volume_name}")
    end

    def destroy_repo_volume!
      system("docker", "volume", "rm", "-f", repo_volume_name, out: File::NULL, err: File::NULL) if agent.uuid.present?
    end

    def migrate_repo_volume_from_container!
      ensure_repo_volume!
      return true if repo_volume_populated?

      source = "#{agent.container_name}:#{REPO_PATH}/."
      destination_mount = "#{repo_volume_name}:/repo"
      cmd = [
        "docker cp #{Shellwords.escape(source)} -",
        "docker run --rm -i -v #{Shellwords.escape(destination_mount)} busybox tar xf - -C /repo"
      ].join(" | ")
      raise SandboxError, "failed to migrate #{REPO_PATH} into #{repo_volume_name}" unless system(cmd, out: File::NULL, err: File::NULL)
    end

    def repo_volume_populated?
      result = docker_capture(
        "run", "--rm", "-v", "#{repo_volume_name}:/repo:ro", "busybox", "sh", "-c",
        "test -n \"$(find /repo -mindepth 1 -print -quit)\""
      )
      result[:ok]
    end

    def run_container!
      ensure_repo_volume!
      args = [
        "docker", "run", "-d",
        "--name", agent.container_name,
        "--network", Agents::Config.network,
        "--restart", "unless-stopped",
        "--memory", "#{agent.container_memory_mb}m",
        "--cpu-shares", agent.container_cpu_shares.to_s,
        "-v", "#{Agents::Volume.new(agent).volume_name}:/home/agent/identity",
        "-v", "chaos-home-#{agent.uuid}:/home/agent/.chaos",
        "-v", "#{repo_volume_name}:#{REPO_PATH}",
        "-e", "AGENT_ID=#{agent.uuid}",
        "-e", "AGENT_SLUG=#{agent_slug}",
        "-e", "AGENT_PROVIDER=#{agent_provider}",
        "-e", "AGENT_DEFAULT_MODEL=#{agent_model}",
        "-e", "TRIGGER_BEARER_TOKEN=#{agent.trigger_bearer_token}",
        "-e", "HELIXKIT_BEARER_TOKEN=#{agent.outbound_api_token}",
        "-e", "HELIXKIT_APP_URL=#{Agents::Config.internal_url}",
      ]
      args += provider_env_args
      args += [ "-p", "127.0.0.1::4000" ] if Agents::Config.publish_ports?
      args << agent.container_image

      _stdout, stderr, status = Open3.capture3(*args)
      raise SandboxError, "docker run failed: #{stderr}" unless status.success?
    end

    def refresh_dev_endpoint!
      stdout, stderr, status = Open3.capture3("docker", "port", agent.container_name, "4000/tcp")
      raise SandboxError, "docker port failed: #{stderr}" unless status.success?

      host_port = stdout.lines.first.to_s.strip
      raise SandboxError, "docker port returned no mapping for #{agent.container_name}" if host_port.blank?

      host, port = host_port.split(":", 2)
      host = "127.0.0.1" if host == "0.0.0.0" || host == "::"
      agent.update!(endpoint_url: "http://#{host}:#{port}")
    end

    def wait_for_health!
      30.times do
        return true if healthy?
        sleep 1
      end
      raise SandboxError, "container did not become healthy within 30s"
    end

    def agent_slug
      agent.name.to_s.parameterize.presence || agent.uuid
    end

    def agent_provider
      self.class.chaos_provider_for(agent)
    end

    def self.chaos_provider_for(agent)
      agent.model_id.to_s.split("/").first.presence || "anthropic"
    end

    def self.chaos_model_for(agent)
      model_id = agent.model_id.to_s
      model_config = Chat::MODELS.find { |model| model[:model_id] == model_id }
      return model_config[:provider_model_id] if model_config&.dig(:provider_model_id).present?

      provider, model = model_id.split("/", 2)
      return model_id if model.blank?
      provider == "openrouter" ? model_id : model
    end

    def agent_model
      self.class.chaos_model_for(agent)
    end

    def provider_env_args
      {
        "ANTHROPIC_API_KEY" => credential(:anthropic, :claude),
        "OPENAI_API_KEY" => credential(:openai, :open_ai),
        "OPENROUTER_API_KEY" => credential(:openrouter, :openrouter),
        "GEMINI_API_KEY" => credential(:gemini, :gemini),
        "XAI_API_KEY" => credential(:xai, :xai)
      }.filter_map do |name, value|
        value.present? ? [ "-e", "#{name}=#{value}" ] : nil
      end.flatten
    end

    def credential(env_name, credential_name)
      ENV["#{env_name.to_s.upcase}_API_KEY"].presence ||
        Rails.application.credentials.dig(:ai, credential_name, :api_token).presence
    end

  end
end
