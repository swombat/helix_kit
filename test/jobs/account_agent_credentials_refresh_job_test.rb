require "test_helper"

class AccountAgentCredentialsRefreshJobTest < ActiveJob::TestCase

  test "recreates externally hosted account agents" do
    agent = agents(:research_assistant)
    agent.update!(runtime: "external", container_name: "hk-agent-test")
    sandbox = Minitest::Mock.new
    sandbox.expect(:active_turn?, false)
    sandbox.expect(:recreate!, true)

    Agents::Sandbox.stub(:new, sandbox) do
      AccountAgentCredentialsRefreshJob.perform_now(agent.account.id)
    end

    assert sandbox.verify
  end

  test "defers an active agent runtime" do
    agent = agents(:research_assistant)
    agent.update!(runtime: "external", container_name: "hk-agent-test")
    sandbox = Minitest::Mock.new
    sandbox.expect(:active_turn?, true)

    Agents::Sandbox.stub(:new, sandbox) do
      assert_enqueued_with(
        job: AccountAgentCredentialsRefreshJob,
        args: [ agent.account.id, agent.id ]
      ) do
        AccountAgentCredentialsRefreshJob.perform_now(agent.account.id)
      end
    end

    assert sandbox.verify
  end

end
