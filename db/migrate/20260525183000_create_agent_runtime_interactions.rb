class CreateAgentRuntimeInteractions < ActiveRecord::Migration[8.1]

  def change
    create_table :agent_runtime_interactions do |t|
      t.references :agent, null: false, foreign_key: true
      t.references :chat, foreign_key: true
      t.string :trigger_kind, null: false
      t.string :session_id
      t.string :conversation_obfuscated_id
      t.string :requested_by
      t.string :endpoint_url
      t.integer :transport_status
      t.string :runtime_status
      t.integer :runtime_returncode
      t.text :request_text
      t.text :stdout
      t.text :stderr
      t.jsonb :response_body, null: false, default: {}
      t.string :error_class
      t.text :error_message
      t.datetime :started_at, null: false
      t.datetime :finished_at
      t.integer :duration_ms
      t.timestamps

      t.index [ :agent_id, :created_at ]
      t.index [ :chat_id, :created_at ]
      t.index :session_id
    end
  end

end
