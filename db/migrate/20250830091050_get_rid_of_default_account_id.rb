class GetRidOfDefaultAccountId < ActiveRecord::Migration[8.0]

  def change
    remove_column :users, :default_account_id
  end

end
