class CreateNotices < ActiveRecord::Migration[8.0]

  def change
    create_table :notices do |t|
      t.string :scope, null: false
      t.references :account, null: true, foreign_key: true
      t.string :notice_type, null: false
      t.jsonb :params, null: false, default: {}
      t.text :body
      t.datetime :expires_at, null: false
      t.references :created_by, null: true, foreign_key: { to_table: :users }

      t.timestamps
    end

    add_index :notices, :expires_at
    add_index :notices, [ :scope, :account_id, :expires_at ]
  end

end
