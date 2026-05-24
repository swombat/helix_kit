module Agents
  class Network

    def self.ensure!
      network = Agents::Config.network
      return true if system("docker", "network", "inspect", network, out: File::NULL, err: File::NULL)
      system("docker", "network", "create", network) || raise("failed to create docker network #{network}")
    end

  end
end
