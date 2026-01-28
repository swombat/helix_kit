require "test_helper"

class ConversationInitiationJobTest < ActiveSupport::TestCase

  setup do
    @agent = agents(:research_assistant)
    @account = @agent.account

    # Create recent activity to make the account "active"
    @activity_log = AuditLog.create!(
      account: @account,
      action: "test_activity"
    )
  end

  test "does not run outside daytime GMT hours (3am)" do
    nighttime = Time.utc(2026, 1, 28, 3, 0, 0)

    travel_to nighttime do
      assert_no_enqueued_jobs(only: AgentInitiationDecisionJob) do
        ConversationInitiationJob.perform_now
      end
    end
  end

  test "does not run outside daytime GMT hours (21:00)" do
    nighttime = Time.utc(2026, 1, 28, 21, 0, 0)

    travel_to nighttime do
      assert_no_enqueued_jobs(only: AgentInitiationDecisionJob) do
        ConversationInitiationJob.perform_now
      end
    end
  end

  test "schedules decision jobs for eligible agents during daytime" do
    daytime = Time.utc(2026, 1, 28, 12, 0, 0)

    travel_to daytime do
      assert_enqueued_with(job: AgentInitiationDecisionJob) do
        ConversationInitiationJob.perform_now
      end
    end
  end

  test "only schedules jobs for agents from active accounts" do
    inactive_account = accounts(:another_team)
    inactive_agent = inactive_account.agents.create!(
      name: "Inactive Agent",
      model_id: "openrouter/auto",
      active: true
    )

    AuditLog.where(account: inactive_account).delete_all
    Message.joins(:chat).where(chats: { account_id: inactive_account.id }).delete_all

    daytime = Time.utc(2026, 1, 28, 12, 0, 0)
    travel_to daytime do
      ConversationInitiationJob.perform_now
    end

    # Decision jobs should be enqueued for active account agents only
    enqueued = queue_adapter.enqueued_jobs.select { |j| j["job_class"] == "AgentInitiationDecisionJob" }
    agent_ids = enqueued.map { |j| j["arguments"].first["_aj_globalid"] }

    refute agent_ids.any? { |gid| gid.include?("/#{inactive_agent.id}") },
           "Should not schedule job for agent in inactive account"
  end

end
