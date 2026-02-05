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

  test "schedules decision jobs with nighttime flag at 3am GMT" do
    travel_to Time.utc(2026, 1, 28, 3, 0, 0) do
      assert_enqueued_with(job: AgentInitiationDecisionJob) do
        ConversationInitiationJob.perform_now
      end

      enqueued = queue_adapter.enqueued_jobs.select { |j| j["job_class"] == "AgentInitiationDecisionJob" }
      assert enqueued.all? { |j| j["arguments"].last["nighttime"] == true },
             "Night-time jobs should pass nighttime: true"
    end
  end

  test "schedules decision jobs with nighttime flag at 21:00 GMT" do
    travel_to Time.utc(2026, 1, 28, 21, 0, 0) do
      assert_enqueued_with(job: AgentInitiationDecisionJob) do
        ConversationInitiationJob.perform_now
      end

      enqueued = queue_adapter.enqueued_jobs.select { |j| j["job_class"] == "AgentInitiationDecisionJob" }
      assert enqueued.all? { |j| j["arguments"].last["nighttime"] == true },
             "Night-time jobs should pass nighttime: true"
    end
  end

  test "schedules decision jobs without nighttime flag during daytime" do
    travel_to Time.utc(2026, 1, 28, 12, 0, 0) do
      assert_enqueued_with(job: AgentInitiationDecisionJob) do
        ConversationInitiationJob.perform_now
      end

      enqueued = queue_adapter.enqueued_jobs.select { |j| j["job_class"] == "AgentInitiationDecisionJob" }
      assert enqueued.all? { |j| j["arguments"].last["nighttime"] == false },
             "Daytime jobs should pass nighttime: false"
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
