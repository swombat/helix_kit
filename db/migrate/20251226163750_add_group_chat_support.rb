class AddGroupChatSupport < ActiveRecord::Migration[8.1]

  def change
    add_column :chats, :manual_responses, :boolean, default: false, null: false
    add_index :chats, :manual_responses

    add_reference :messages, :agent, foreign_key: true, null: true

    create_table :chat_agents do |t|
      t.references :chat, null: false, foreign_key: true
      t.references :agent, null: false, foreign_key: true
      t.datetime :created_at, null: false
    end

    add_index :chat_agents, [ :chat_id, :agent_id ], unique: true
  end

end
