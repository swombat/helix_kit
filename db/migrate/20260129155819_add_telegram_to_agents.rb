class AddTelegramToAgents < ActiveRecord::Migration[8.1]

  def change
    add_column :agents, :telegram_bot_token, :string
    add_column :agents, :telegram_bot_username, :string
    add_column :agents, :telegram_webhook_token, :string

    add_index :agents, :telegram_webhook_token, unique: true
  end

end
