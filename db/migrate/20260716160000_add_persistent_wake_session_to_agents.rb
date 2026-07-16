class AddPersistentWakeSessionToAgents < ActiveRecord::Migration[8.1]

  def change
    add_column :agents, :persistent_wake_session, :boolean, default: false, null: false
  end

end
