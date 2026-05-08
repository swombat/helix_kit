require "test_helper"

class AgentMigrationSweeperJobTest < ActiveJob::TestCase

  setup do
    @user = users(:user_1)
    @agent = agents(:research_assistant)
  end

  test "reverts stale migrating agents and revokes scoped key" do
    key = ApiKey.generate_for(@user, name: "stale", agent: @agent)
    @agent.update!(
      runtime: "migrating",
      uuid: SecureRandom.uuid_v7,
      trigger_bearer_token: "tr_stale",
      outbound_api_key: key,
      migration_started_at: 25.hours.ago
    )

    assert_difference "ApiKey.count", -1 do
      AgentMigrationSweeperJob.perform_now
    end

    @agent.reload
    assert_equal "inline", @agent.runtime
    assert_nil @agent.trigger_bearer_token
    assert_nil @agent.outbound_api_key
    assert_nil @agent.migration_started_at
  end

  test "leaves fresh migrating agents alone" do
    key = ApiKey.generate_for(@user, name: "fresh", agent: @agent)
    @agent.update!(
      runtime: "migrating",
      uuid: SecureRandom.uuid_v7,
      trigger_bearer_token: "tr_fresh",
      outbound_api_key: key,
      migration_started_at: 1.hour.ago
    )

    assert_no_difference "ApiKey.count" do
      AgentMigrationSweeperJob.perform_now
    end

    assert_equal "migrating", @agent.reload.runtime
    assert_equal key, @agent.outbound_api_key
  end

end
