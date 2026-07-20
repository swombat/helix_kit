class ReplaceHalfHourlyWakeWithHeartbeatFrequency < ActiveRecord::Migration[8.1]

  def up
    add_column :agents, :heartbeat_wakes_per_day, :integer, default: 2, null: false

    execute <<~SQL
      UPDATE agents
      SET heartbeat_wakes_per_day = 48
      WHERE half_hourly_wake = TRUE
    SQL

    execute <<~SQL
      UPDATE agents
      SET heartbeat_wakes_per_day = 1
      WHERE name = 'Claude' AND runtime = 'external'
    SQL

    remove_column :agents, :half_hourly_wake
  end

  def down
    add_column :agents, :half_hourly_wake, :boolean, default: false, null: false

    execute <<~SQL
      UPDATE agents
      SET half_hourly_wake = TRUE
      WHERE heartbeat_wakes_per_day = 48
    SQL

    remove_column :agents, :heartbeat_wakes_per_day
  end

end
