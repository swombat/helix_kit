class AddPasswordResetTokenToUsers < ActiveRecord::Migration[8.0]

  def change
    add_column :users, :password_reset_token, :string
    add_index :users, :password_reset_token, unique: true
    add_column :users, :password_reset_sent_at, :datetime
  end

end
