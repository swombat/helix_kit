class CreateWhiteboards < ActiveRecord::Migration[8.1]

  def change
    create_table :whiteboards do |t|
      t.references :account, null: false, foreign_key: true
      t.string :name, null: false
      t.string :summary, limit: 250
      t.text :content
      t.integer :revision, null: false, default: 1
      t.references :last_edited_by, polymorphic: true
      t.datetime :last_edited_at
      t.datetime :deleted_at

      t.timestamps
    end

    add_index :whiteboards, [ :account_id, :name ], unique: true, where: "deleted_at IS NULL"
    add_index :whiteboards, [ :account_id, :deleted_at ]
  end

end
