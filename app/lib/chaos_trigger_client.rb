class ChaosTriggerClient

  def initialize(endpoint_url, trigger_bearer_token)
    require "net/http"

    @endpoint_url = endpoint_url
    @trigger_bearer_token = trigger_bearer_token
  end

  def request_response(conversation_id:, requested_by:, session_id:, request:, trigger_kind: "conversation")
    raise ArgumentError, "endpoint_url is missing" if endpoint_url.blank?
    raise ArgumentError, "trigger bearer token is missing" if trigger_bearer_token.blank?

    uri = URI("#{endpoint_url.to_s.delete_suffix('/')}/trigger")
    http_request = Net::HTTP::Post.new(uri)
    http_request["Authorization"] = "Bearer #{trigger_bearer_token}"
    http_request["Content-Type"] = "application/json"
    http_request.body = {
      trigger_kind: trigger_kind,
      conversation_id: conversation_id,
      requested_by: requested_by,
      session_id: session_id,
      request: request
    }.to_json

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == "https", open_timeout: 5, read_timeout: 60) do |http|
      http.request(http_request)
    end

    {
      status: response.code.to_i,
      body: parse_body(response.body)
    }
  end

  private

  attr_reader :endpoint_url, :trigger_bearer_token

  def parse_body(body)
    JSON.parse(body)
  rescue JSON::ParserError
    { "raw" => body.to_s }
  end

end
