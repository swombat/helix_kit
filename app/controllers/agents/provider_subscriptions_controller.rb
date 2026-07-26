class Agents::ProviderSubscriptionsController < ApplicationController

  include AgentScoped

  before_action :require_account_owner!

  def show
    result = auth_client.status(provider:)
    persist_status!(result)
    render json: result
  rescue AgentProviderAuthClient::Error => e
    render_client_error(e)
  end

  def create
    result = auth_client.start(provider:)
    @agent.use_provider_auth_mode!(provider, "oauth_account")
    render json: result
  rescue AgentProviderAuthClient::Error => e
    render_client_error(e)
  end

  def update
    mode = params.require(:auth_mode)
    if mode == "oauth_account" && @agent.provider_connection(provider)["status"] != "connected"
      render json: { error: "Connect the provider account before selecting subscription mode" },
             status: :unprocessable_entity
      return
    end
    @agent.use_provider_auth_mode!(provider, mode)
    audit("update_agent_provider_auth_mode", @agent, provider:, auth_mode: mode)
    render json: { provider:, auth_mode: mode }
  rescue ArgumentError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def destroy
    result = auth_client.disconnect(provider:)
    @agent.clear_provider_connection!(provider)
    audit("disconnect_agent_provider_subscription", @agent, provider:)
    render json: result
  rescue AgentProviderAuthClient::Error => e
    render_client_error(e)
  end

  def cancel
    render json: auth_client.cancel(provider:)
  rescue AgentProviderAuthClient::Error => e
    render_client_error(e)
  end

  private

  def auth_client
    @auth_client ||= AgentProviderAuthClient.new(@agent)
  end

  def provider
    @provider ||= params.require(:provider).to_s
  end

  def persist_status!(result)
    case result["status"]
    when "connected"
      @agent.record_provider_connection!(
        provider,
        email: result["email"],
        plan: result["plan"],
        status: "connected",
        connected_at: @agent.provider_connection(provider)["connected_at"] || Time.current.iso8601
      )
    when "none"
      @agent.clear_provider_connection!(provider) if @agent.provider_connection(provider).present?
    end
  end

  def render_client_error(error)
    render json: { error: error.message }, status: error.status || :bad_gateway
  end

end
