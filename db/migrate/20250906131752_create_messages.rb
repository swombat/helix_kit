class CreateMessages < ActiveRecord::Migration[8.0]

  def change
    create_table :messages do |t|
      t.belongs_to :chat, null: false, foreign_key: true
      t.belongs_to :user, null: true, foreign_key: true # nil for AI messages
      t.string :role, null: false # 'user', 'assistant', 'system'
      t.text :content
      t.string :model_id
      t.integer :input_tokens
      t.integer :output_tokens
      t.references :tool_call
      t.timestamps
    end

    add_index :messages, [ :chat_id, :created_at ]
  end

end
