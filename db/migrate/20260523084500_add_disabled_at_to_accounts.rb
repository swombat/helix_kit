class AddDisabledAtToAccounts < ActiveRecord::Migration[8.1]
  def change
    add_column :accounts, :disabled_at, :datetime
    add_index :accounts, :disabled_at
  end
end
