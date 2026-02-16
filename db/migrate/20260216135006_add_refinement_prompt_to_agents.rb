class AddRefinementPromptToAgents < ActiveRecord::Migration[8.1]
  def change
    add_column :agents, :refinement_prompt, :text
  end
end
