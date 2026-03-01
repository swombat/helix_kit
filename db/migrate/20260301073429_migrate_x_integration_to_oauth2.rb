class MigrateXIntegrationToOauth2 < ActiveRecord::Migration[8.1]

  def change
    remove_column :x_integrations, :api_key, :text
    remove_column :x_integrations, :api_key_secret, :text
    remove_column :x_integrations, :access_token_secret, :text
    add_column :x_integrations, :refresh_token, :text
    add_column :x_integrations, :token_expires_at, :datetime
  end

end
