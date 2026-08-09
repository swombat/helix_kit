class AllowMultipleCredentialsPerServiceIdentity < ActiveRecord::Migration[8.1]

  def change
    add_column :service_connections, :credential_fingerprint, :string

    remove_index :service_connections,
                 name: "index_service_connections_on_account_provider_subject"
    add_index :service_connections,
              [ :account_id, :provider, :external_subject_id ],
              unique: true,
              where: "external_subject_id IS NOT NULL AND credential_fingerprint IS NULL",
              name: "index_service_connections_on_account_provider_subject"
    add_index :service_connections,
              [ :account_id, :provider, :credential_fingerprint ],
              unique: true,
              where: "credential_fingerprint IS NOT NULL",
              name: "index_service_connections_on_account_provider_credential"
  end

end
