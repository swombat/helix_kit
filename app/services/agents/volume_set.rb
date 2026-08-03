module Agents
  class VolumeSet

    attr_reader :agent

    def initialize(agent)
      @agent = agent
    end

    def names
      {
        identity: "hk-agent-#{agent.uuid}-identity",
        chaos: "chaos-home-#{agent.uuid}",
        repo: "hk-agent-#{agent.uuid}-repo",
        work: "hk-agent-#{agent.uuid}-work",
        state: "hk-agent-#{agent.uuid}-state"
      }
    end

    def each(&block)
      names.each(&block)
    end

  end
end
