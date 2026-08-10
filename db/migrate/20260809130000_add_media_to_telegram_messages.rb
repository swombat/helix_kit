class AddMediaToTelegramMessages < ActiveRecord::Migration[8.1]

  def change
    add_column :telegram_messages, :media_kind, :string
    add_column :telegram_messages, :caption, :text
    add_column :telegram_messages, :transcription, :text
    add_column :telegram_messages, :media_status, :string
    add_column :telegram_messages, :media_error, :string
    add_column :telegram_messages, :media_metadata, :jsonb, null: false, default: {}
    add_column :telegram_messages, :wake_enqueued_at, :datetime
  end

end
