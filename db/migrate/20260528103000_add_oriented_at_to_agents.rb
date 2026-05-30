class AddOrientedAtToAgents < ActiveRecord::Migration[8.1]
  def change
    add_column :agents, :oriented_at, :datetime
  end
end
