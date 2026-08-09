require "net/http"
require "json"

module Services
  class OuraAdapter

    AUTHORIZE_URL = "https://cloud.ouraring.com/oauth/authorize"
    TOKEN_URL = "https://api.ouraring.com/oauth/token"
    IDENTITY_URL = "https://api.ouraring.com/v2/usercollection/personal_info"
    REVOKE_URL = "https://api.ouraring.com/oauth/revoke"

    class Error < Services::AdapterError; end

    attr_reader :definition

    def initialize(definition)
      @definition = definition
    end

    def authorization_url(attempt, state:, redirect_uri:)
      params = {
        response_type: "code",
        client_id: client_id,
        redirect_uri: redirect_uri,
        scope: attempt.requested_scopes.join(" "),
        state: state
      }
      "#{AUTHORIZE_URL}?#{params.to_query}"
    end

    def exchange_code(code:, attempt:, redirect_uri:)
      data = token_request(
        grant_type: "authorization_code",
        code: code,
        redirect_uri: redirect_uri
      )
      identity = fetch_identity(data.fetch("access_token"))

      {
        external_subject_id: identity.fetch("id").to_s,
        external_identity: identity["email"].presence || attempt.user.email_address,
        match_existing_by: :connected_user,
        credential_kind: "oauth2",
        credential_payload: credential_payload(data),
        credential_metadata: {
          "granted_scopes" => data["scope"].to_s.split.presence || attempt.requested_scopes,
          "credential_strategy" => definition.credential_strategy
        }
      }
    end

    def current_access_token(connection)
      connection.with_lock do
        connection.reload
        payload = connection.credential_payload_hash
        return payload.fetch("access_token") if token_fresh?(payload)

        refresh_token = payload["refresh_token"].presence ||
          raise(Error, "Oura refresh token is unavailable; reconnect Oura")
        data = token_request(grant_type: "refresh_token", refresh_token: refresh_token)
        refreshed_payload = credential_payload(data, previous_refresh_token: refresh_token)
        connection.replace_credential_payload_without_reconciliation!(refreshed_payload)
        refreshed_payload.fetch("access_token")
      end
    end

    def revoke(connection)
      token = connection.credential_payload_hash["access_token"]
      return if token.blank?

      uri = URI(REVOKE_URL)
      uri.query = URI.encode_www_form(access_token: token)
      Net::HTTP.get_response(uri)
    rescue StandardError => e
      Rails.logger.warn("Oura token revocation failed for service connection #{connection.id}: #{e.class}")
    end

    private

    def token_request(params)
      response = Net::HTTP.post_form(URI(TOKEN_URL), params.merge(
        client_id: client_id,
        client_secret: client_secret
      ))
      parse_success(response, "Oura token exchange")
    end

    def fetch_identity(access_token)
      uri = URI(IDENTITY_URL)
      request = Net::HTTP::Get.new(uri)
      request["Authorization"] = "Bearer #{access_token}"
      parse_success(
        Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) { |http| http.request(request) },
        "Oura identity lookup"
      )
    end

    def credential_payload(data, previous_refresh_token: nil)
      {
        "access_token" => data.fetch("access_token"),
        "refresh_token" => data["refresh_token"].presence || previous_refresh_token,
        "expires_at" => data["expires_in"].to_i.seconds.from_now.utc.iso8601
      }.compact
    end

    def token_fresh?(payload)
      expires_at = Time.iso8601(payload["expires_at"].to_s)
      payload["access_token"].present? && expires_at > 1.day.from_now
    rescue ArgumentError
      false
    end

    def parse_success(response, label)
      raise Error, "#{label} failed (#{response.code})" unless response.is_a?(Net::HTTPSuccess)
      JSON.parse(response.body)
    rescue JSON::ParserError
      raise Error, "#{label} returned invalid JSON"
    end

    def client_id
      Rails.application.credentials.dig(:oura, :client_id) ||
        raise(ArgumentError, "Oura client_id is not configured")
    end

    def client_secret
      Rails.application.credentials.dig(:oura, :client_secret) ||
        raise(ArgumentError, "Oura client_secret is not configured")
    end

  end
end
