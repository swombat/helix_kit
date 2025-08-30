class AddIsSiteAdminToUsersAndAccounts < ActiveRecord::Migration[8.0]

  def change
    add_column :users, :is_site_admin, :boolean, default: false, null: false
    add_column :accounts, :is_site_admin, :boolean, default: false, null: false
  end

end
