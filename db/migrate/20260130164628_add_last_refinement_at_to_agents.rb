class AddLastRefinementAtToAgents < ActiveRecord::Migration[8.0]

  def change
    add_column :agents, :last_refinement_at, :datetime
  end

end
