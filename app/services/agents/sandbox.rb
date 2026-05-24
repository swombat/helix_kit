module Agents
  class Sandbox

    class SandboxError < StandardError; end

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
        start!
      else
        run_container!
      end

      refresh_dev_endpoint! if Agents::Config.publish_ports?
      wait_for_health!
      agent.update!(runtime: "external", health_state: "healthy", consecutive_health_failures: 0)
    end

    def stop!
      system("docker", "stop", agent.container_name, out: File::NULL, err: File::NULL)
    end

    def start!
      system("docker", "start", agent.container_name, out: File::NULL, err: File::NULL) || raise(SandboxError, "failed to start #{agent.container_name}")
    end

    def remove!(delete_volume: false)
      system("docker", "rm", "-f", agent.container_name, out: File::NULL, err: File::NULL)
      Agents::Volume.new(agent).destroy! if delete_volume
    end

    def healthy?
      uri = URI("#{Agents::Endpoint.url_for(agent)}/health")
      Net::HTTP.get_response(uri).code == "200"
    rescue StandardError
      false
    end

    private

    def container_exists?
      system("docker", "container", "inspect", agent.container_name, out: File::NULL, err: File::NULL)
    end

    def run_container!
      args = [
        "docker", "run", "-d",
        "--name", agent.container_name,
        "--network", Agents::Config.network,
        "--restart", "unless-stopped",
        "--memory", "#{agent.container_memory_mb}m",
        "--cpu-shares", agent.container_cpu_shares.to_s,
        "-v", "#{Agents::Volume.new(agent).volume_name}:/home/agent/identity",
        "-v", "chaos-home-#{agent.uuid}:/home/agent/.chaos",
        "-e", "AGENT_ID=#{agent.uuid}",
        "-e", "AGENT_SLUG=#{agent_slug}",
        "-e", "AGENT_PROVIDER=#{agent_provider}",
        "-e", "AGENT_DEFAULT_MODEL=#{agent.model_id}",
        "-e", "TRIGGER_BEARER_TOKEN=#{agent.trigger_bearer_token}",
        "-e", "HELIXKIT_BEARER_TOKEN=#{agent.outbound_api_token}",
        "-e", "HELIXKIT_APP_URL=#{Agents::Config.internal_url}",
        "-e", "ANTHROPIC_API_KEY=#{Rails.application.credentials.dig(:anthropic_api_key)}"
      ]
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
      agent.model_id.to_s.split("/").first.presence || "anthropic"
    end

  end
end
