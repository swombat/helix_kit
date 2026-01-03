class AddArchiveAndDiscardToChats < ActiveRecord::Migration[8.1]

  def change
    add_column :chats, :archived_at, :datetime
    add_column :chats, :discarded_at, :datetime

    add_index :chats, :archived_at
    add_index :chats, :discarded_at
  end

end
