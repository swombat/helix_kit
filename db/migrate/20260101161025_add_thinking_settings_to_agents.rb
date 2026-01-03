class AddThinkingSettingsToAgents < ActiveRecord::Migration[8.1]

  def change
    add_column :agents, :thinking_enabled, :boolean, default: false, null: false
    add_column :agents, :thinking_budget, :integer, default: 10000
  end

end
