class AddScheduledWakesEnabledToAgents < ActiveRecord::Migration[8.1]

  def up
    add_column :agents, :scheduled_wakes_enabled, :boolean, default: true, null: false

    execute <<~SQL
      UPDATE agents
      SET scheduled_wakes_enabled = FALSE
      WHERE name = 'Claude'
    SQL
  end

  def down
    remove_column :agents, :scheduled_wakes_enabled
  end

end
