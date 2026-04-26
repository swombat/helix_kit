class AddPausedToAgents < ActiveRecord::Migration[8.0]
  def change
    add_column :agents, :paused, :boolean, default: false, null: false
    add_index :agents, [ :account_id, :paused ]
  end
end
