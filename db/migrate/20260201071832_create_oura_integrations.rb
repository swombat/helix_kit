class CreateOuraIntegrations < ActiveRecord::Migration[8.1]

  def change
    create_table :oura_integrations do |t|
      t.references :user, null: false, foreign_key: true, index: { unique: true }

      # OAuth tokens (encrypted via Rails attribute encryption)
      t.text :access_token
      t.text :refresh_token
      t.datetime :token_expires_at

      # Cached health data (refreshed periodically)
      t.jsonb :health_data, default: {}
      t.datetime :health_data_synced_at

      # User preference - single toggle
      t.boolean :enabled, default: true, null: false

      t.timestamps
    end
  end

end
