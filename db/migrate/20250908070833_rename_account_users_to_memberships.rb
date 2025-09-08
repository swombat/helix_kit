class RenameAccountUsersToMemberships < ActiveRecord::Migration[8.0]

  def change
    rename_table :account_users, :memberships
  end

end
