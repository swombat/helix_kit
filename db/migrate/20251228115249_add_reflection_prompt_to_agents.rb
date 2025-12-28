class AddReflectionPromptToAgents < ActiveRecord::Migration[8.1]
  def change
    add_column :agents, :reflection_prompt, :text
  end
end
