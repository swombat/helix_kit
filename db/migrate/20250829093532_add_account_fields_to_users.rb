class AddAccountFieldsToUsers < ActiveRecord::Migration[8.0]

  def change
    add_reference :users, :default_account, foreign_key: { to_table: :accounts }
    # Temporary flag for migration tracking
    add_column :users, :migrated_to_accounts, :boolean, default: false
  end

end
