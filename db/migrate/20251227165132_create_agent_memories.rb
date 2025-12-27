class CreateAgentMemories < ActiveRecord::Migration[8.1]

  def change
    create_table :agent_memories do |t|
      t.references :agent, null: false, foreign_key: true
      t.text :content, null: false
      t.integer :memory_type, null: false, default: 0
      t.timestamps
    end

    add_index :agent_memories, [ :agent_id, :memory_type ]
    add_index :agent_memories, [ :agent_id, :created_at ]
  end

end
