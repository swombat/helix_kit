require "vcr"


IGNORED_HEADERS = [
  "Accept-Encoding",
  "Authorization",
  "User-Agent",
  "Accept",
  "X-Auth-Token"
]

VCR_RECORD_MODE = ENV["RECORD_CASSETTES"] == "1" ? :new_episodes : :none

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

  # Use existing cassettes by default. Set RECORD_CASSETTES=1 when intentionally
  # refreshing or adding cassette interactions.
  # config.default_cassette_options = {
  #   record: :new_episodes,
  #   match_requests_on: [:method, :uri, :body],  # Match on method, URI and body for more accurate matches
  #   serialize_with: :yaml,
  #   persist_with: :file_system
  # }

  config.default_cassette_options = {
    record: VCR_RECORD_MODE,
    match_requests_on: [ :method, :uri, :body ],
    serialize_with: :yaml,
    persist_with: :file_system
  }

  # Create debug log
  config.debug_logger = File.open(File.join(Rails.root, "log", "vcr_debug.log"), "w")

  # Filter sensitive API keys
  config.filter_sensitive_data("<OPENAI_API_KEY>") { Rails.application.credentials.dig(:ai, :open_ai, :api_token) }
  config.filter_sensitive_data("<CLAUDE_API_KEY>") { Rails.application.credentials.dig(:ai, :claude, :api_token) if Rails.application.credentials.dig(:ai, :claude).present? }
  config.filter_sensitive_data("<OPENROUTER_API_KEY>") { Rails.application.credentials.dig(:ai, :openrouter, :api_token) if Rails.application.credentials.dig(:ai, :openrouter).present? }
  config.filter_sensitive_data("<GEMINI_API_KEY>") { Rails.application.credentials.dig(:ai, :gemini, :api_token) if Rails.application.credentials.dig(:ai, :gemini).present? }
  config.filter_sensitive_data("<XAI_API_KEY>") { Rails.application.credentials.dig(:ai, :xai, :api_token) if Rails.application.credentials.dig(:ai, :xai).present? }
  config.filter_sensitive_data("<AWS_ACCESS_KEY_ID>") { Rails.application.credentials.dig(:aws, :access_key_id) }
  config.filter_sensitive_data("<AWS_SECRET_ACCESS_KEY>") { Rails.application.credentials.dig(:aws, :secret_access_key) }
  config.filter_sensitive_data("<HONEYBADGER_API_KEY>") { Rails.application.credentials.dig(:honeybadger, :api_key) }
  config.filter_sensitive_data("<GITHUB_TEST_ACCESS_TOKEN>") { ENV["GITHUB_TEST_ACCESS_TOKEN"] }
  config.filter_sensitive_data("telegram-test-bot-token") { ENV["TELEGRAM_TEST_BOT_TOKEN"] }
  config.filter_sensitive_data("12345") { ENV["TELEGRAM_TEST_CHAT_ID"] }

  # Filter X/Twitter OAuth 2.0 credentials
  config.filter_sensitive_data("<X_CLIENT_ID>") { Rails.application.credentials.dig(:x, :client_id) }
  config.filter_sensitive_data("<X_CLIENT_SECRET>") { Rails.application.credentials.dig(:x, :client_secret) }

  # Filter random tempfile names in OpenAI audio transcription requests
  config.before_record do |interaction|
    IGNORED_HEADERS.each do |header|
      interaction.request.headers.delete(header)
      interaction.response.headers.delete(header)
    end

    if interaction.request.uri.include?("api.openai.com/v1/audio/transcriptions")
      # Replace random tempfile names with a fixed name to prevent cassette recreation
      interaction.request.body = interaction.request.body.gsub(/tempfile\d{8}-\d+-\w+_\d+\.mp3/, "tempfile-fixed-for-tests.mp3")
    end

    if interaction.request.uri.include?("api.telegram.org")
      interaction.request.uri = interaction.request.uri.gsub(%r{/bot[^/]+/}, "/bottelegram-test-bot-token/")
      interaction.request.body = interaction.request.body.gsub(/"chat_id":\s*-?\d+/, '"chat_id":12345') if interaction.request.body
      interaction.request.body = interaction.request.body.gsub(/"secret_token":"[^"]+"/, '"secret_token":"telegram-webhook-secret"') if interaction.request.body
      interaction.request.body = interaction.request.body.gsub(%r{/telegram/webhook/[A-Za-z0-9_-]+}, "/telegram/webhook/telegram-webhook-token") if interaction.request.body

      if interaction.response.body
        interaction.response.body = interaction.response.body.gsub(%r{/telegram/webhook/[A-Za-z0-9_-]+}, "/telegram/webhook/telegram-webhook-token")
        interaction.response.body = interaction.response.body.gsub(/"url":"[^"]*\/telegram\/webhook\/[^"]+"/, '"url":"https://example.test/telegram/webhook/telegram-webhook-token"')
        interaction.response.body = interaction.response.body.gsub(/"chat":\{[^{}]*"id":-?\d+/, '"chat":{"id":12345')
        interaction.response.body = interaction.response.body.gsub(/"from":\{[^{}]*\}/, '"from":{"id":67890,"is_bot":true,"first_name":"Test Bot","username":"test_bot"}')
        interaction.response.body = interaction.response.body.gsub(/"chat":\{[^{}]*\}/, '"chat":{"id":12345,"first_name":"Test","last_name":"User","username":"test_user","type":"private"}')
        interaction.response.body = interaction.response.body.gsub(/"message_id":\d+/, '"message_id":1')
      end
    end
  end
end
