class AddExternalRuntimeFieldsToAgents < ActiveRecord::Migration[8.1]

  def change
    add_reference :api_keys, :agent, foreign_key: true, null: true, index: false
    add_index :api_keys, :agent_id, unique: true, where: "agent_id IS NOT NULL"

    add_column :agents, :runtime, :string, default: "inline", null: false
    add_column :agents, :uuid, :uuid, null: true
    add_index :agents, :uuid, unique: true
    add_column :agents, :endpoint_url, :string
    add_column :agents, :trigger_bearer_token, :string
    add_reference :agents, :outbound_api_key, foreign_key: { to_table: :api_keys }, null: true
    add_column :agents, :migration_started_at, :datetime
    add_column :agents, :last_announced_at, :datetime
    add_column :agents, :last_health_check_at, :datetime
    add_column :agents, :health_state, :string, default: "unknown", null: false
    add_column :agents, :consecutive_health_failures, :integer, default: 0, null: false
    add_index :agents, :runtime
  end

end
