class RenameCanFetchUrlsToWebAccess < ActiveRecord::Migration[8.1]

  def change
    rename_column :chats, :can_fetch_urls, :web_access
  end

end
