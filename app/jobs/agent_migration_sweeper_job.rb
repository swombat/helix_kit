class AgentMigrationSweeperJob < ApplicationJob

  queue_as :default

  def perform
    Agent.where(runtime: "migrating")
      .where("migration_started_at < ?", 24.hours.ago)
      .find_each do |agent|
        api_key = agent.outbound_api_key
        agent.update!(
          runtime: "inline",
          migration_started_at: nil,
          trigger_bearer_token: nil,
          outbound_api_key: nil
        )
        api_key&.destroy!
      end
  end

end
