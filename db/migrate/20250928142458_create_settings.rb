class CreateSettings < ActiveRecord::Migration[8.0]

  def change
    create_table :settings do |t|
      t.string :site_name, null: false, default: "HelixKit"
      t.boolean :allow_signups, null: false, default: true
      t.boolean :allow_chats, null: false, default: true
      t.timestamps
    end
  end

end
