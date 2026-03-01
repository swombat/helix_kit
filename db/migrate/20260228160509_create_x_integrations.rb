class CreateXIntegrations < ActiveRecord::Migration[8.1]

  def change
    create_table :x_integrations do |t|
      t.references :account, null: false, foreign_key: true, index: { unique: true }
      t.text :api_key
      t.text :api_key_secret
      t.text :access_token
      t.text :access_token_secret
      t.string :x_username
      t.boolean :enabled, default: true, null: false
      t.timestamps
    end
  end

end
