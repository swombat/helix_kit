module OuraApi

  extend ActiveSupport::Concern

  OURA_AUTHORIZE_URL = "https://cloud.ouraring.com/oauth/authorize"
  OURA_TOKEN_URL = "https://api.ouraring.com/oauth/token"
  OURA_API_BASE = "https://api.ouraring.com/v2"
  SCOPES = %w[email personal daily heartrate].freeze

  class Error < StandardError; end

  included do
    encrypts :access_token
    encrypts :refresh_token
  end

  def authorization_url(state:, redirect_uri:)
    params = {
      response_type: "code",
      client_id: oura_credentials(:client_id),
      redirect_uri: redirect_uri,
      scope: SCOPES.join(" "),
      state: state
    }
    "#{OURA_AUTHORIZE_URL}?#{params.to_query}"
  end

  def exchange_code!(code:, redirect_uri:)
    response = HTTParty.post(OURA_TOKEN_URL, body: {
      grant_type: "authorization_code",
      code: code,
      client_id: oura_credentials(:client_id),
      client_secret: oura_credentials(:client_secret),
      redirect_uri: redirect_uri
    })

    save_tokens!(response)
  end

  def refresh_tokens!
    return if token_fresh?

    response = HTTParty.post(OURA_TOKEN_URL, body: {
      grant_type: "refresh_token",
      refresh_token: refresh_token,
      client_id: oura_credentials(:client_id),
      client_secret: oura_credentials(:client_secret)
    })

    save_tokens!(response)
  end

  def token_fresh?
    token_expires_at.present? && token_expires_at > 1.day.from_now
  end

  def connected?
    access_token.present? && token_expires_at&.future?
  end

  def fetch_health_data
    today = Date.current
    yesterday = today - 1.day

    {
      "sleep" => fetch_endpoint("/usercollection/daily_sleep", yesterday, today),
      "readiness" => fetch_endpoint("/usercollection/daily_readiness", yesterday, today),
      "activity" => fetch_endpoint("/usercollection/daily_activity", yesterday, today)
    }
  end

  def revoke_token
    return unless access_token
    HTTParty.get("https://api.ouraring.com/oauth/revoke", query: { access_token: access_token })
  rescue StandardError => e
    Rails.logger.warn("Oura token revocation failed: #{e.message}")
  end

  private

  def oura_credentials(key)
    Rails.application.credentials.dig(:oura, key) ||
      raise(ArgumentError, "Oura #{key} not configured in credentials")
  end

  def save_tokens!(response)
    raise Error, "Token exchange failed: #{response.code}" unless response.success?

    data = JSON.parse(response.body)
    update!(
      access_token: data["access_token"],
      refresh_token: data["refresh_token"],
      token_expires_at: data["expires_in"].to_i.seconds.from_now
    )
  end

  def fetch_endpoint(path, start_date, end_date)
    response = HTTParty.get(
      "#{OURA_API_BASE}#{path}",
      headers: { "Authorization" => "Bearer #{access_token}" },
      query: { start_date: start_date.to_s, end_date: end_date.to_s }
    )

    if response.code == 401
      update!(access_token: nil, token_expires_at: nil)
      return nil
    end

    if response.code == 429
      Rails.logger.warn("Oura rate limit hit for user #{user_id}")
      return nil
    end

    return nil unless response.success?
    JSON.parse(response.body)["data"]
  rescue StandardError => e
    Rails.logger.error("Oura API error for #{path}: #{e.message}")
    nil
  end

end
