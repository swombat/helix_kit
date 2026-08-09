class Accounts::ServiceConnectionsController < ApplicationController

  before_action :set_connection

  def update
    unless @connection.manageable_by?(Current.user)
      redirect_back_or_to account_path(current_account), alert: "You cannot manage this connection"
      return
    end

    attributes = connection_params
    if attributes[:freely_provisionable].present? && !@connection.owner?(Current.user)
      attributes.delete(:freely_provisionable)
    end
    @connection.update!(attributes)
    audit(:update_service_connection, @connection,
          provider: @connection.provider,
          enabled_for_new_agents: @connection.enabled_for_new_agents?,
          freely_provisionable: @connection.freely_provisionable?)
    redirect_back fallback_location: account_path(current_account), notice: "Service connection updated"
  end

  def destroy
    unless @connection.manageable_by?(Current.user)
      redirect_back_or_to account_path(current_account), alert: "You cannot manage this connection"
      return
    end

    @connection.disconnect!
    audit(:disconnect_service, @connection, provider: @connection.provider)
    @connection.destroy!
    redirect_back fallback_location: account_path(current_account), notice: "Service disconnected"
  end

  private

  def set_connection
    @connection = current_account.service_connections.find_by_public_id!(params[:id])
  end

  def connection_params
    params.require(:service_connection).permit(:label, :enabled_for_new_agents, :freely_provisionable)
  end

end
