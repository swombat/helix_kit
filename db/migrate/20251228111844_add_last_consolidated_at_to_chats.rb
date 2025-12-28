class AddLastConsolidatedAtToChats < ActiveRecord::Migration[8.1]

  def change
    add_column :chats, :last_consolidated_at, :datetime
    add_column :chats, :last_consolidated_message_id, :bigint

    add_index :chats, :last_consolidated_at
  end

end
