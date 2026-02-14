class AddRefinementThresholdToAgents < ActiveRecord::Migration[8.1]

  def change
    add_column :agents, :refinement_threshold, :float
  end

end
