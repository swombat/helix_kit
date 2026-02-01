class OuraIntegrationController < ApplicationController

  before_action :set_integration, except: %i[show create]

  def show
    integration = Current.user.oura_integration || Current.user.build_oura_integration

    render inertia: "settings/oura_integration", props: {
      integration: integration_json(integration)
    }
  end

  def create
    state = SecureRandom.hex(32)
    session[:oura_oauth_state] = state
    session[:oura_oauth_state_expires_at] = 10.minutes.from_now.to_i

    integration = Current.user.oura_integration || Current.user.create_oura_integration!
    redirect_to integration.authorization_url(state: state, redirect_uri: oura_redirect_uri),
                allow_other_host: true
  end

  def callback
    if params[:error]
      redirect_to oura_integration_path, alert: "Authorization was denied"
      return
    end

    expected_state = session.delete(:oura_oauth_state)
    expires_at = session.delete(:oura_oauth_state_expires_at)

    unless expected_state == params[:state] && Time.current.to_i < expires_at.to_i
      redirect_to oura_integration_path, alert: "Invalid or expired authorization"
      return
    end

    unless @integration
      redirect_to oura_integration_path, alert: "No integration found"
      return
    end

    @integration.exchange_code!(code: params[:code], redirect_uri: oura_redirect_uri)

    SyncOuraDataJob.perform_later(@integration.id)

    redirect_to oura_integration_path, notice: "Oura Ring connected successfully"
  rescue OuraApi::Error => e
    redirect_to oura_integration_path, alert: "Failed to connect: #{e.message}"
  end

  def update
    redirect_to oura_integration_path and return unless @integration

    @integration.update!(integration_params)
    redirect_to oura_integration_path, notice: "Settings updated"
  end

  def destroy
    @integration&.disconnect!

    redirect_to oura_integration_path, notice: "Oura Ring disconnected"
  end

  def sync
    if @integration&.connected?
      SyncOuraDataJob.perform_later(@integration.id)
      redirect_to oura_integration_path, notice: "Sync started"
    else
      redirect_to oura_integration_path, alert: "Not connected to Oura"
    end
  end

  private

  def set_integration
    @integration = Current.user.oura_integration
  end

  def oura_redirect_uri
    base = Rails.application.credentials.dig(:app, :url) || request.base_url
    "#{base}/oura_integration/callback"
  end

  def integration_params
    params.require(:oura_integration).permit(:enabled)
  end

  def integration_json(integration)
    {
      id: integration.id,
      enabled: integration.enabled?,
      connected: integration.connected?,
      health_data_synced_at: integration.health_data_synced_at&.iso8601,
      token_expires_at: integration.token_expires_at&.iso8601
    }
  end

end
