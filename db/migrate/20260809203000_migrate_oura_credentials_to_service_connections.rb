class MigrateOuraCredentialsToServiceConnections < ActiveRecord::Migration[8.1]

  def up
    OuraIntegration.reset_column_information
    ServiceConnection.reset_column_information
    AgentServiceAccess.reset_column_information

    OuraIntegration.includes(user: :accounts).find_each do |integration|
      next if integration.access_token.blank? && integration.refresh_token.blank?

      user = integration.user
      account = target_account_for(user, integration)
      next unless account

      connection = integration.service_connection ||
        account.service_connections.find_by(provider: "oura", connected_by_user: user) ||
        account.service_connections.new

      payload = {
        "access_token" => integration.access_token,
        "refresh_token" => integration.refresh_token,
        "expires_at" => integration.token_expires_at&.utc&.iso8601
      }.compact

      connection.assign_attributes(
        connected_by_user: user,
        legacy_oura_integration: nil,
        provider: "oura",
        external_subject_id: connection.external_subject_id.presence || "migrated-oura-user-#{user.id}",
        external_identity: user.email_address,
        label: connection.label.presence || "#{user.display_name} — Oura",
        management_scope: "personal",
        credential_kind: "oauth2",
        credential_metadata: {
          "granted_scopes" => OuraApi::SCOPES,
          "credential_strategy" => "refresh_broker"
        },
        status: "connected",
        enabled_for_new_agents: false,
        freely_provisionable: nexus_account?(account)
      )
      connection.credential_payload_hash = payload
      # This migration runs before credential_fingerprint is added. Skip the
      # current model's validations so restoring an older database does not
      # invoke validations for columns that do not exist at this schema version.
      connection.save!(validate: false)

      unless connection.reload.credential_payload_hash.slice("access_token", "refresh_token") ==
             payload.slice("access_token", "refresh_token")
        raise ActiveRecord::MigrationError, "Oura credential verification failed for integration #{integration.id}"
      end

      provision_all_residents!(connection) if nexus_account?(account)
      connection.update_columns(
        enabled_for_new_agents: nexus_account?(account),
        freely_provisionable: nexus_account?(account),
        updated_at: Time.current
      )

      integration.update_columns(
        access_token: nil,
        refresh_token: nil,
        token_expires_at: nil,
        updated_at: Time.current
      )
    end
  end

  def down
    ServiceConnection.where(provider: "oura").includes(:connected_by_user).find_each do |connection|
      payload = connection.credential_payload_hash
      integration = OuraIntegration.find_or_initialize_by(user: connection.connected_by_user)
      integration.update!(
        access_token: payload["access_token"],
        refresh_token: payload["refresh_token"],
        token_expires_at: parse_time(payload["expires_at"])
      )
      connection.destroy!
    end
  end

  private

  def target_account_for(user, integration)
    return integration.service_connection.account if integration.service_connection

    nexus = user.accounts.find { |account| nexus_account?(account) }
    nexus || user.accounts.personal.find { |account| account.personal_account_for?(user) } || user.accounts.first
  end

  def nexus_account?(account)
    account.name.casecmp("Nexus").zero? || account.slug.to_s.casecmp("nexus").zero?
  end

  def provision_all_residents!(connection)
    connection.account.agents.find_each do |agent|
      access = connection.agent_service_accesses.find_or_initialize_by(agent: agent)
      access.assign_attributes(
        enabled: true,
        follows_default: true,
        provisioning_status: "pending",
        provisioning_error_code: nil
      )
      access.save!
    end
  end

  def parse_time(value)
    Time.iso8601(value) if value.present?
  end

end
