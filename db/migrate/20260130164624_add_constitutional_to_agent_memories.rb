class AddConstitutionalToAgentMemories < ActiveRecord::Migration[8.0]

  def change
    add_column :agent_memories, :constitutional, :boolean, default: false, null: false
  end

end
