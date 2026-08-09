class Accounts::OuraAdoptionsController < ApplicationController

  def create
    integration = Current.user.oura_integration
    unless integration&.connected?
      redirect_to account_personal_services_path(current_account), alert: "Connect Oura first"
      return
    end

    if integration.service_connection && integration.service_connection.account_id != current_account.id
      redirect_to account_personal_services_path(current_account),
                  alert: "This Oura credential is already attached to another account; connect Oura again for a separate account"
      return
    end

    connection = current_account.service_connections.find_or_initialize_by(
      legacy_oura_integration: integration
    )
    connection.assign_attributes(
      connected_by_user: Current.user,
      provider: "oura",
      external_subject_id: "legacy-oura-user-#{Current.user.id}",
      external_identity: Current.user.email_address,
      label: "#{Current.user.display_name} — Oura",
      management_scope: "personal",
      credential_kind: "legacy_reference",
      credential_metadata: {
        "granted_scopes" => OuraApi::SCOPES,
        "credential_strategy" => "refresh_broker"
      },
      status: "connected"
    )
    connection.save!

    audit(:adopt_legacy_oura, connection, legacy_oura_integration_id: integration.id)
    redirect_to account_personal_services_path(current_account),
                notice: "Oura is now available for resident access; existing credentials were not changed"
  end

end
