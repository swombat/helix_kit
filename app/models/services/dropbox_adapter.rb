require "net/http"
require "json"
require "base64"
require "digest"

module Services
  class DropboxAdapter

    AUTHORIZE_URL = "https://www.dropbox.com/oauth2/authorize"
    TOKEN_URL = "https://api.dropboxapi.com/oauth2/token"
    IDENTITY_URL = "https://api.dropboxapi.com/2/users/get_current_account"
    REVOKE_URL = "https://api.dropboxapi.com/2/auth/token/revoke"

    class Error < Services::AdapterError; end

    attr_reader :definition

    def initialize(definition)
      @definition = definition
    end

    def authorization_url(attempt, state:, redirect_uri:)
      verifier = attempt.pkce_verifier
      challenge = Base64.urlsafe_encode64(Digest::SHA256.digest(verifier), padding: false)
      "#{AUTHORIZE_URL}?#{{
        response_type: "code",
        client_id: client_id,
        redirect_uri: redirect_uri,
        token_access_type: "offline",
        scope: attempt.requested_scopes.join(" "),
        state: state,
        code_challenge: challenge,
        code_challenge_method: "S256"
      }.to_query}"
    end

    def exchange_code(code:, attempt:, redirect_uri:)
      response = Net::HTTP.post_form(URI(TOKEN_URL), {
        code: code,
        grant_type: "authorization_code",
        client_id: client_id,
        redirect_uri: redirect_uri,
        code_verifier: attempt.pkce_verifier
      }.compact)
      data = parse_success(response, "Dropbox token exchange")
      identity = fetch_identity(data.fetch("access_token"))

      {
        external_subject_id: identity.fetch("account_id"),
        external_identity: identity["email"].presence || identity.dig("name", "display_name"),
        credential_kind: "oauth2",
        credential_payload: {
          "access_token" => data.fetch("access_token"),
          "refresh_token" => data["refresh_token"],
          "expires_at" => data["expires_in"].to_i.seconds.from_now.utc.iso8601,
          "client_id" => client_id,
          "token_url" => TOKEN_URL
        },
        credential_metadata: {
          "granted_scopes" => data["scope"].to_s.split.presence || attempt.requested_scopes,
          "credential_strategy" => definition.credential_strategy
        }
      }
    end

    def revoke(connection)
      token = connection.credential_payload_hash["access_token"]
      return if token.blank?

      uri = URI(REVOKE_URL)
      request = Net::HTTP::Post.new(uri)
      request["Authorization"] = "Bearer #{token}"
      Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) { |http| http.request(request) }
    rescue StandardError => e
      Rails.logger.warn("Dropbox token revocation failed for service connection #{connection.id}: #{e.class}")
    end

    private

    def fetch_identity(access_token)
      uri = URI(IDENTITY_URL)
      request = Net::HTTP::Post.new(uri)
      request["Authorization"] = "Bearer #{access_token}"
      request["Content-Type"] = "application/json"
      request.body = "null"
      parse_success(
        Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) { |http| http.request(request) },
        "Dropbox identity lookup"
      )
    end

    def parse_success(response, label)
      raise Error, "#{label} failed (#{response.code})" unless response.is_a?(Net::HTTPSuccess)
      JSON.parse(response.body)
    rescue JSON::ParserError
      raise Error, "#{label} returned invalid JSON"
    end

    def client_id
      Rails.application.credentials.dig(:dropbox, :app_key) ||
        Rails.application.credentials.dig(:dropbox, :client_id) ||
        ENV["DROPBOX_CLIENT_ID"] ||
        raise(ArgumentError, "Dropbox app_key is not configured")
    end

  end
end
