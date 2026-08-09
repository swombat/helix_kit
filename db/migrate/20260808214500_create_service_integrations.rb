class CreateServiceIntegrations < ActiveRecord::Migration[8.1]

  def change
    create_table :service_authorization_attempts do |t|
      t.references :account, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :provider, null: false
      t.string :management_scope, null: false
      t.string :access_profile, null: false
      t.jsonb :requested_scopes, null: false, default: []
      t.string :state_digest, null: false
      t.text :pkce_verifier
      t.string :return_path
      t.datetime :expires_at, null: false
      t.datetime :consumed_at
      t.timestamps

      t.index :state_digest, unique: true
    end

    create_table :service_connections do |t|
      t.references :account, null: false, foreign_key: true
      t.references :connected_by_user, null: false, foreign_key: { to_table: :users }
      t.references :legacy_oura_integration, foreign_key: { to_table: :oura_integrations }
      t.string :provider, null: false
      t.string :external_subject_id
      t.string :external_identity
      t.string :label
      t.string :management_scope, null: false, default: "personal"
      t.string :credential_kind, null: false
      t.text :credential_payload
      t.jsonb :credential_metadata, null: false, default: {}
      t.string :status, null: false, default: "connected"
      t.boolean :enabled_for_new_agents, null: false, default: false
      t.boolean :freely_provisionable, null: false, default: false
      t.integer :credential_revision, null: false, default: 1
      t.timestamps

      t.index [ :account_id, :provider, :external_subject_id ],
              unique: true,
              where: "external_subject_id IS NOT NULL",
              name: "index_service_connections_on_account_provider_subject"
      t.index :legacy_oura_integration_id,
              unique: true,
              where: "legacy_oura_integration_id IS NOT NULL",
              name: "index_service_connections_on_unique_legacy_oura"
    end

    create_table :agent_service_accesses do |t|
      t.references :agent, null: false, foreign_key: true
      t.references :service_connection, null: false, foreign_key: true
      t.boolean :enabled, null: false, default: true
      t.boolean :follows_default, null: false, default: false
      t.integer :provisioned_revision
      t.datetime :provisioned_at
      t.string :provisioning_status
      t.string :provisioning_error_code
      t.timestamps

      t.index [ :agent_id, :service_connection_id ], unique: true
    end
  end

end
