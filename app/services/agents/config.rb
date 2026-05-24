module Agents
  module Config

    module_function

    def network
      ENV.fetch("HELIXKIT_AGENTS_NETWORK", "helixkit_agents")
    end

    def default_image
      ENV.fetch("HELIXKIT_AGENT_IMAGE_DEFAULT", default_image_fallback)
    end

    def default_image_fallback
      local_development? ? "helixkit-agent-runtime:local" : "helixkit-agent-runtime:latest"
    end

    def internal_url
      ENV.fetch("HELIXKIT_AGENT_INTERNAL_URL") do
        local_development? ? "http://host.docker.internal:3000" : raise(KeyError, "HELIXKIT_AGENT_INTERNAL_URL is required")
      end
    end

    def sandbox_host
      ENV.fetch("HELIXKIT_SANDBOX_HOST") do
        local_development? ? "local-docker-desktop" : raise(KeyError, "HELIXKIT_SANDBOX_HOST is required")
      end
    end

    def publish_ports?
      ActiveModel::Type::Boolean.new.cast(ENV.fetch("HELIXKIT_AGENT_PUBLISH_PORTS") { local_development? })
    end

    def backups_enabled?
      ActiveModel::Type::Boolean.new.cast(ENV.fetch("HELIXKIT_AGENT_BACKUPS_ENABLED", !local_development?))
    end

    def local_development?
      Rails.env.development? || Rails.env.test?
    end

  end
end
