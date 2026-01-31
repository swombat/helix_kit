class AddDiscardedAtToAgentMemories < ActiveRecord::Migration[8.1]

  def change
    add_column :agent_memories, :discarded_at, :datetime
    add_index :agent_memories, :discarded_at
  end

end
