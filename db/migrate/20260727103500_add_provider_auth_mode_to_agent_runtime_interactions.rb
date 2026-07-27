class AddProviderAuthModeToAgentRuntimeInteractions < ActiveRecord::Migration[8.1]

  def change
    add_column :agent_runtime_interactions, :provider_auth_mode, :string,
               default: "api_key", null: false
  end

end
