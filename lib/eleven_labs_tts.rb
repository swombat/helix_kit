class ElevenLabsTts

  class Error < StandardError; end

  API_BASE = "https://api.elevenlabs.io/v1/text-to-speech"
  MODEL_ID = "eleven_v3"
  READ_TIMEOUT = 60
  OPEN_TIMEOUT = 10

  DEFAULT_VOICE_SETTINGS = {
    stability: 0.5,
    similarity_boost: 0.75,
    style: 0.0,
    use_speaker_boost: true,
    speed: 1.0
  }.freeze

  def self.synthesize(text, voice_id:)
    new.synthesize(text, voice_id: voice_id)
  end

  def synthesize(text, voice_id:)
    uri = URI("#{API_BASE}/#{voice_id}")

    request = Net::HTTP::Post.new(uri)
    request["xi-api-key"] = api_key
    request["Content-Type"] = "application/json"
    request["Accept"] = "audio/mpeg"

    request.body = {
      text: text,
      model_id: MODEL_ID,
      voice_settings: DEFAULT_VOICE_SETTINGS
    }.to_json

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true,
      read_timeout: READ_TIMEOUT, open_timeout: OPEN_TIMEOUT) { |http| http.request(request) }

    handle_response(response)
  end

  private

  def api_key
    Rails.application.credentials.dig(:ai, :eleven_labs, :api_token) ||
      raise(Error, "ElevenLabs API key not configured")
  end

  def handle_response(response)
    case response.code.to_i
    when 200
      response.body
    when 401
      raise Error, "Invalid ElevenLabs API key"
    when 429
      raise Error, "ElevenLabs rate limit exceeded. Please try again later."
    when 422
      error_msg = JSON.parse(response.body).dig("detail", "message") rescue "Invalid request"
      raise Error, "Speech synthesis failed: #{error_msg}"
    else
      Rails.logger.error("ElevenLabs TTS error: #{response.code} - #{response.body}")
      raise Error, "Speech synthesis service unavailable. Please try again."
    end
  end

end
