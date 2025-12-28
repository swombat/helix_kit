class AddMemoryReflectionPromptToAgents < ActiveRecord::Migration[8.1]
  def change
    add_column :agents, :memory_reflection_prompt, :text
  end
end
