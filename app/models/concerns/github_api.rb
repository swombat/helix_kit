require "net/http"
require "json"

module GithubApi

  extend ActiveSupport::Concern

  GITHUB_AUTHORIZE_URL = "https://github.com/login/oauth/authorize"
  GITHUB_TOKEN_URL = "https://github.com/login/oauth/access_token"
  GITHUB_API_BASE = "https://api.github.com"
  API_VERSION = "2022-11-28"

  class Error < StandardError; end

  included do
    encrypts :access_token
  end

  def authorization_url(state:, redirect_uri:)
    params = {
      client_id: github_credentials(:client_id),
      redirect_uri: redirect_uri,
      scope: "repo",
      state: state,
      allow_signup: false
    }
    "#{GITHUB_AUTHORIZE_URL}?#{params.to_query}"
  end

  def exchange_code!(code:, redirect_uri:)
    uri = URI(GITHUB_TOKEN_URL)
    request = Net::HTTP::Post.new(uri)
    request["Accept"] = "application/json"
    request.set_form_data(
      client_id: github_credentials(:client_id),
      client_secret: github_credentials(:client_secret),
      code: code,
      redirect_uri: redirect_uri
    )

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) { |http| http.request(request) }
    raise Error, "Token exchange failed: #{response.code}" unless response.is_a?(Net::HTTPSuccess)

    data = JSON.parse(response.body)
    raise Error, "No access token returned" unless data["access_token"]

    user_info = fetch_user(data["access_token"])

    update!(
      access_token: data["access_token"],
      github_username: user_info["login"]
    )
  end

  def connected?
    access_token.present?
  end

  def fetch_repos
    get("/user/repos", { visibility: "all", sort: "updated", direction: "desc", per_page: 100 })
  end

  def fetch_recent_commits(limit: 10)
    return [] unless repository_full_name.present?

    commits = get("/repos/#{repository_full_name}/commits", { per_page: limit })
    return [] unless commits.is_a?(Array)

    commits.map do |c|
      {
        "sha" => c["sha"]&.slice(0, 8),
        "message" => c.dig("commit", "message")&.lines&.first&.strip,
        "author" => c.dig("commit", "author", "name"),
        "date" => c.dig("commit", "author", "date")
      }
    end
  end

  private

  def github_credentials(key)
    Rails.application.credentials.dig(:github, key) ||
      raise(ArgumentError, "GitHub #{key} not configured in credentials")
  end

  def fetch_user(token)
    uri = URI("#{GITHUB_API_BASE}/user")
    request = Net::HTTP::Get.new(uri)
    request["Authorization"] = "Bearer #{token}"
    request["Accept"] = "application/vnd.github+json"
    request["X-GitHub-Api-Version"] = API_VERSION

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) { |http| http.request(request) }
    raise Error, "Failed to fetch user info" unless response.is_a?(Net::HTTPSuccess)

    JSON.parse(response.body)
  end

  def get(path, params = {})
    uri = URI("#{GITHUB_API_BASE}#{path}")
    uri.query = URI.encode_www_form(params) if params.any?

    request = Net::HTTP::Get.new(uri)
    request["Authorization"] = "Bearer #{access_token}"
    request["Accept"] = "application/vnd.github+json"
    request["X-GitHub-Api-Version"] = API_VERSION

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) { |http| http.request(request) }

    if response.code == "401"
      update!(access_token: nil, github_username: nil)
      raise Error, "GitHub token revoked or invalid"
    end

    if response.code == "403" && response["X-RateLimit-Remaining"] == "0"
      Rails.logger.warn("GitHub rate limit hit for account #{account_id}")
      return nil
    end

    return nil unless response.is_a?(Net::HTTPSuccess)
    JSON.parse(response.body)
  rescue JSON::ParserError => e
    Rails.logger.error("GitHub API JSON parse error: #{e.message}")
    nil
  end

end
