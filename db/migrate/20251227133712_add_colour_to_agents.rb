class AddColourToAgents < ActiveRecord::Migration[8.1]
  def change
    add_column :agents, :colour, :string
  end
end
