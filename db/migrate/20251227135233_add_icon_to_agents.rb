class AddIconToAgents < ActiveRecord::Migration[8.1]
  def change
    add_column :agents, :icon, :string
  end
end
