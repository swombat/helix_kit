class CreateApiKeyRequests < ActiveRecord::Migration[8.1]

  def change
    create_table :api_key_requests do |t|
      t.string :request_token, null: false
      t.string :client_name, null: false
      t.bigint :api_key_id
      t.string :status, null: false, default: "pending"
      t.text :approved_token_encrypted
      t.datetime :expires_at, null: false
      t.timestamps
    end

    add_index :api_key_requests, :request_token, unique: true
    add_foreign_key :api_key_requests, :api_keys
  end

end
