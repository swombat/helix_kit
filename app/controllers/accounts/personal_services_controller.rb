class Accounts::PersonalServicesController < ApplicationController

  def show
    render inertia: "accounts/personal_services", props: {
      account: current_account.as_json,
      services: Services::Definition.all
        .select { |definition| definition.supports_management_scope?("personal") }
        .map(&:as_json),
      connections: current_account.service_connections.personal
        .where(connected_by_user: Current.user)
        .includes(:connected_by_user)
        .map { |connection| connection.as_connection_json(current_user: Current.user) },
      agents: current_account.agents.by_name.map { |agent| { id: agent.to_param, name: agent.name } }
    }
  end

end
