class AddHalfHourlyWakeToAgents < ActiveRecord::Migration[8.1]

  def change
    add_column :agents, :half_hourly_wake, :boolean, default: false, null: false
  end

end
