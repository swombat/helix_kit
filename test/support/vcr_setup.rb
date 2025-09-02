require "vcr"


IGNORED_HEADERS = [
  "Accept-Encoding",
  "Authorization",
  "User-Agent",
  "Accept",
  "X-Auth-Token"
]

VCR.configure do |config|
  config.cassette_library_dir = "test/vcr_cassettes"
  config.hook_into :faraday, :webmock

  # Don't allow any real HTTP connections when using VCR
  config.allow_http_connections_when_no_cassette = false

  # Ignore requests to localhost
  config.ignore_request do |request|
    URI(request.uri).host == "127.0.0.1" || URI(request.uri).host == "localhost"
  end
  # Configure VCR to properly handle binary data
  config.preserve_exact_body_bytes do |http_message|
    http_message.body.encoding.name == "ASCII-8BIT" ||
    !http_message.body.valid_encoding?
  end

  # Use existing cassettes, allow new ones if needed
  # config.default_cassette_options = {
  #   record: :new_episodes,  # Use existing cassettes but allow recording new interactions
  #   match_requests_on: [:method, :uri, :body],  # Match on method, URI and body for more accurate matches
  #   serialize_with: :yaml,
  #   persist_with: :file_system
  # }

  config.default_cassette_options = {
    record: :new_episodes,
    match_requests_on: [ :method, :uri, :body ],
    serialize_with: :yaml,
    persist_with: :file_system
  }

  # Create debug log
  config.debug_logger = File.open(File.join(Rails.root, "log", "vcr_debug.log"), "w")

  # Filter sensitive API keys
  config.filter_sensitive_data("<OPENAI_API_KEY>") { Rails.application.credentials.dig(:ai, :open_ai, :api_token) }
  config.filter_sensitive_data("<CLAUDE_API_KEY>") { Rails.application.credentials.dig(:ai, :claude, :api_token) if Rails.application.credentials.dig(:ai, :claude).present? }
  config.filter_sensitive_data("<OPENROUTER_API_KEY>") { Rails.application.credentials.dig(:ai, :openrouter, :api_token) if Rails.application.credentials.dig(:ai, :claude).present? }
  config.filter_sensitive_data("<AWS_ACCESS_KEY_ID>") { Rails.application.credentials.dig(:aws, :access_key_id) }
  config.filter_sensitive_data("<AWS_SECRET_ACCESS_KEY>") { Rails.application.credentials.dig(:aws, :secret_access_key) }
  config.filter_sensitive_data("<HONEYBADGER_API_KEY>") { Rails.application.credentials.dig(:honeybadger, :api_key) }

  # Filter random tempfile names in OpenAI audio transcription requests
  config.before_record do |interaction|
    if interaction.request.uri.include?("api.openai.com/v1/audio/transcriptions")
      # Replace random tempfile names with a fixed name to prevent cassette recreation
      interaction.request.body = interaction.request.body.gsub(/tempfile\d{8}-\d+-\w+_\d+\.mp3/, "tempfile-fixed-for-tests.mp3")
    end
  end
end
