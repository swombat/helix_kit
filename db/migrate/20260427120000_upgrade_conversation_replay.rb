class UpgradeConversationReplay < ActiveRecord::Migration[8.1]

  def up
    add_column :messages,   :replay_payload,        :jsonb
    add_column :messages,   :cached_tokens,         :integer
    add_column :messages,   :cache_creation_tokens, :integer
    add_column :messages,   :reasoning_skip_reason, :string
    add_column :tool_calls, :replay_payload,        :jsonb

    add_index :messages, :reasoning_skip_reason, where: "reasoning_skip_reason IS NOT NULL"

    # Relocate existing thinking_signature values into replay_payload before dropping the column.
    Message.reset_column_information
    Message.where.not(thinking_signature: [ nil, "" ]).find_each do |msg|
      signature = msg[:thinking_signature]
      next if signature.blank?

      payload = {
        "provider" => "anthropic",
        "thinking" => {
          "text"      => msg.thinking_text,
          "signature" => signature
        }
      }
      msg.update_columns(replay_payload: payload)
    end

    remove_column :messages, :thinking_signature
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end

end
