class Api::V1::ServiceConnectionTokensController < ActionController::API

  include ApiAuthentication

  def show
    connection = current_api_agent.service_connections
      .merge(AgentServiceAccess.enabled)
      .find_by_public_id!(params[:service_connection_id])

    unless connection.legacy_oura_integration
      render json: { error: "This connection does not use the refresh broker" }, status: :unprocessable_entity
      return
    end

    integration = connection.legacy_oura_integration
    integration.refresh_tokens! unless integration.token_fresh?
    render json: {
      access_token: integration.access_token,
      expires_at: integration.token_expires_at&.utc&.iso8601
    }
  rescue OuraApi::Error => e
    render json: { error: e.message }, status: :bad_gateway
  end

end
