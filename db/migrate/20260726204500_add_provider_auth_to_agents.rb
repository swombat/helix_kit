class AddProviderAuthToAgents < ActiveRecord::Migration[8.1]

  def change
    add_column :agents, :provider_auth_modes, :jsonb, default: {}, null: false
    add_column :agents, :provider_connections, :jsonb, default: {}, null: false
  end

end
