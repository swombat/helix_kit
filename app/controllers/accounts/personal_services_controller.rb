class Accounts::PersonalServicesController < ApplicationController

  def show
    render inertia: "accounts/personal_services", props: {
      account: current_account.as_json,
      services: Services::Definition.all
        .select { |definition| definition.supports_management_scope?("personal") }
        .map(&:as_json),
      connections: current_account.service_connections.personal
        .where(connected_by_user: Current.user)
        .includes(:connected_by_user, :legacy_oura_integration)
        .map { |connection| connection.as_connection_json(current_user: Current.user) },
      agents: current_account.agents.by_name.map { |agent| { id: agent.to_param, name: agent.name } },
      legacy_oura: legacy_oura_json
    }
  end

  private

  def legacy_oura_json
    integration = Current.user.oura_integration
    return unless integration

    {
      connected: integration.connected?,
      enabled: integration.enabled?,
      adopted: integration.service_connection.present?,
      adopted_account_id: integration.service_connection&.account_id,
      health_data_synced_at: integration.health_data_synced_at&.iso8601
    }
  end

end
