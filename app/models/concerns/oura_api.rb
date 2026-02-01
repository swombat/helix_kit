require "net/http"
require "json"

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
    response = post_form(OURA_TOKEN_URL, {
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

    response = post_form(OURA_TOKEN_URL, {
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
    uri = URI("https://api.ouraring.com/oauth/revoke")
    uri.query = URI.encode_www_form(access_token: access_token)
    Net::HTTP.get_response(uri)
  rescue StandardError => e
    Rails.logger.warn("Oura token revocation failed: #{e.message}")
  end

  private

  def oura_credentials(key)
    Rails.application.credentials.dig(:oura, key) ||
      raise(ArgumentError, "Oura #{key} not configured in credentials")
  end

  def save_tokens!(response)
    raise Error, "Token exchange failed: #{response.code}" unless response.is_a?(Net::HTTPSuccess)

    data = JSON.parse(response.body)
    update!(
      access_token: data["access_token"],
      refresh_token: data["refresh_token"],
      token_expires_at: data["expires_in"].to_i.seconds.from_now
    )
  end

  def fetch_endpoint(path, start_date, end_date)
    uri = URI("#{OURA_API_BASE}#{path}")
    uri.query = URI.encode_www_form(start_date: start_date.to_s, end_date: end_date.to_s)

    request = Net::HTTP::Get.new(uri)
    request["Authorization"] = "Bearer #{access_token}"

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) { |http| http.request(request) }

    if response.code == "401"
      update!(access_token: nil, token_expires_at: nil)
      return nil
    end

    if response.code == "429"
      Rails.logger.warn("Oura rate limit hit for user #{user_id}")
      return nil
    end

    return nil unless response.is_a?(Net::HTTPSuccess)
    JSON.parse(response.body)["data"]
  rescue StandardError => e
    Rails.logger.error("Oura API error for #{path}: #{e.message}")
    nil
  end

  def post_form(url, params)
    uri = URI(url)
    Net::HTTP.post_form(uri, params)
  end

end
