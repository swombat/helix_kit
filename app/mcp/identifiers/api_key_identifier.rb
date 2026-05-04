# frozen_string_literal: true

class ApiKeyIdentifier < ActionMCP::GatewayIdentifier

  identifier :user
  authenticates :api_key

  def resolve
    token = extract_bearer_token
    raise Unauthorized, "Missing bearer token" if token.blank?

    api_key = ApiKey.authenticate(token)
    raise Unauthorized, "Invalid API key" unless api_key

    api_key.touch_usage!(@request.remote_ip)
    api_key.user
  end

end
