class Accounts::ServicesController < ApplicationController

  def index
    render inertia: "accounts/services", props: {
      account: current_account.as_json,
      services: Services::Definition.all
        .select { |definition| definition.supports_management_scope?("account_managed") }
        .map(&:as_json),
      connections: current_account.service_connections.account_managed.includes(:connected_by_user).map do |connection|
        connection.as_connection_json(current_user: Current.user)
      end,
      agents: current_account.agents.by_name.map { |agent| { id: agent.to_param, name: agent.name } },
      can_manage: current_account.service_credentials_manageable_by?(Current.user)
    }
  end

end
