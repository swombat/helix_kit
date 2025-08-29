class CreateAccounts < ActiveRecord::Migration[8.0]

  def change
    create_table :accounts do |t|
      t.string :name, null: false
      t.integer :account_type, null: false, default: 0  # enum: personal/team
      t.string :slug
      t.jsonb :settings, default: {}
      t.timestamps

      t.index :slug, unique: true
      t.index :account_type
    end
  end

end
