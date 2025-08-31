class AddPreferencesToUsers < ActiveRecord::Migration[8.0]

  def change
    add_column :users, :preferences, :json, default: {}
  end

end
