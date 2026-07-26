class AddSubscriptionApiKeysToAccounts < ActiveRecord::Migration[8.1]

  def change
    add_column :accounts, :zai_api_key, :text
    add_column :accounts, :minimax_api_key, :text
  end

end
