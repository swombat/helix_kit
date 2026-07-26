require "test_helper"

module Backup
  class AgentResticTest < ActiveSupport::TestCase

    setup do
      @agent = agents(:research_assistant)
      @agent.uuid = "019f9dbd-4b8b-7c23-80be-770379e5581f"
    end

    test "backs up all persistent hosted-agent volumes read-only" do
      assert_equal [
        "-v", "hk-agent-019f9dbd-4b8b-7c23-80be-770379e5581f-identity:/data/identity:ro",
        "-v", "chaos-home-019f9dbd-4b8b-7c23-80be-770379e5581f:/data/chaos:ro",
        "-v", "hk-agent-019f9dbd-4b8b-7c23-80be-770379e5581f-repo:/data/repo:ro",
        "-v", "hk-agent-019f9dbd-4b8b-7c23-80be-770379e5581f-work:/data/work:ro"
      ], AgentRestic.backup_mounts(@agent)
    end

    test "restores each persistent volume under the restic data root" do
      assert_equal [
        "-v", "hk-agent-019f9dbd-4b8b-7c23-80be-770379e5581f-identity:/restore/data/identity",
        "-v", "chaos-home-019f9dbd-4b8b-7c23-80be-770379e5581f:/restore/data/chaos",
        "-v", "hk-agent-019f9dbd-4b8b-7c23-80be-770379e5581f-repo:/restore/data/repo",
        "-v", "hk-agent-019f9dbd-4b8b-7c23-80be-770379e5581f-work:/restore/data/work"
      ], AgentRestic.restore_mounts(@agent)
    end

  end
end
