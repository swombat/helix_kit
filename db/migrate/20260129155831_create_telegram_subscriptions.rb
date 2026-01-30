class CreateTelegramSubscriptions < ActiveRecord::Migration[8.1]

  def change
    create_table :telegram_subscriptions do |t|
      t.references :agent, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.bigint :telegram_chat_id, null: false
      t.boolean :blocked, default: false
      t.timestamps
    end

    add_index :telegram_subscriptions, [ :agent_id, :user_id ], unique: true
    add_index :telegram_subscriptions, [ :agent_id, :telegram_chat_id ], unique: true
  end

end
