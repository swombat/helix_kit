class AddTelegramDirectMessageHistory < ActiveRecord::Migration[8.1]

  def change
    add_column :telegram_subscriptions, :telegram_username, :string

    create_table :telegram_messages do |t|
      t.references :telegram_subscription, null: false, foreign_key: true
      t.string :role, null: false
      t.text :text, null: false
      t.string :sender_name
      t.string :sender_username
      t.bigint :telegram_message_id
      t.datetime :sent_at, null: false
      t.timestamps
    end

    add_index :telegram_messages,
      [ :telegram_subscription_id, :telegram_message_id ],
      unique: true,
      where: "telegram_message_id IS NOT NULL"
  end

end
