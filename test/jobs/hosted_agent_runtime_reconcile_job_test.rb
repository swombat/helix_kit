require "test_helper"

class HostedAgentRuntimeReconcileJobTest < ActiveJob::TestCase

  setup do
    @agent = agents(:research_assistant)
    @agent.update!(
      runtime: "external",
      uuid: SecureRandom.uuid_v7,
      container_name: "hk-agent-test",
      container_image: "helixkit-agent-runtime:latest",
      health_state: "healthy"
    )
  end

  test "recreates stale hosted sandbox while preserving volumes" do
    sandbox = Minitest::Mock.new
    sandbox.expect(:stale_image?, true)
    sandbox.expect(:active_turn?, false)
    sandbox.expect(:recreate!, true)

    Agents::Sandbox.stub(:new, ->(agent) {
      assert_equal @agent, agent
      sandbox
    }) do
      HostedAgentRuntimeReconcileJob.perform_now(@agent.id)
    end

    sandbox.verify
  end

  test "skips current sandbox" do
    sandbox = Minitest::Mock.new
    sandbox.expect(:stale_image?, false)

    Agents::Sandbox.stub(:new, ->(_agent) { sandbox }) do
      HostedAgentRuntimeReconcileJob.perform_now(@agent.id)
    end

    sandbox.verify
    assert true
  end

  test "retries active stale sandbox later" do
    sandbox = Minitest::Mock.new
    sandbox.expect(:stale_image?, true)
    sandbox.expect(:active_turn?, true)

    assert_enqueued_with(job: HostedAgentRuntimeReconcileJob, args: [ @agent.id ]) do
      Agents::Sandbox.stub(:new, ->(_agent) { sandbox }) do
        HostedAgentRuntimeReconcileJob.perform_now(@agent.id)
      end
    end

    sandbox.verify
  end

end
