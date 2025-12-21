class AddCanFetchUrlsToChats < ActiveRecord::Migration[8.0]

  def change
    add_column :chats, :can_fetch_urls, :boolean, default: false, null: false
    add_index :chats, :can_fetch_urls
  end

end
