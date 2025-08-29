class CreateAccountUsers < ActiveRecord::Migration[8.0]

  def change
    create_table :account_users do |t|
      t.references :account, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :role, null: false, default: 'owner'
      t.string :confirmation_token
      t.datetime :confirmation_sent_at
      t.datetime :confirmed_at
      t.datetime :invited_at
      t.references :invited_by, foreign_key: { to_table: :users }
      t.timestamps

      t.index [ :account_id, :user_id ], unique: true
      t.index :confirmation_token, unique: true
      t.index :confirmed_at
    end
  end

end
