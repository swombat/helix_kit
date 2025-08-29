class ChangePasswordDigestNullableInUsers < ActiveRecord::Migration[8.0]
  def change
    change_column_null :users, :password_digest, true
  end
end
