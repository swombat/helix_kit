class AddBornHostedLifecycleToAgents < ActiveRecord::Migration[8.1]

  def change
    add_column :agents, :birth_committed_at, :datetime
    add_column :agents, :provisioning_started_at, :datetime
    add_column :agents, :identity_seeded_at, :datetime
    add_column :agents, :runtime_ready_at, :datetime
    add_column :agents, :orientation_requested_at, :datetime
    add_column :agents, :orientation_completed_at, :datetime
  end

end
