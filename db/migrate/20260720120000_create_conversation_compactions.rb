class CreateConversationCompactions < ActiveRecord::Migration[8.1]

  def change
    create_table :conversation_compactions do |t|
      t.references :chat, null: false, foreign_key: true
      t.bigint :boundary_message_id, null: false
      t.text :summary, null: false
      t.string :provider, null: false
      t.string :model, null: false
      t.integer :compacted_message_count, null: false
      t.bigint :input_tokens
      t.bigint :output_tokens
      t.bigint :cached_tokens
      t.bigint :cache_creation_tokens
      t.bigint :thinking_tokens

      t.timestamps
    end

    add_index :conversation_compactions, [ :chat_id, :created_at ]
    add_index :conversation_compactions, [ :chat_id, :boundary_message_id ], unique: true
  end

end
