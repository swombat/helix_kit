class GenerateVoiceJob < ApplicationJob

  queue_as :default

  retry_on ElevenLabsTts::Error, wait: 5.seconds, attempts: 3
  discard_on ActiveRecord::RecordNotFound

  def perform(message)
    return if message.voice_audio.attached?
    return unless message.voice_available

    text = message.content_for_speech
    return if text.blank?

    audio_data = ElevenLabsTts.synthesize(text, voice_id: message.agent.voice_id)

    message.voice_audio.attach(
      io: StringIO.new(audio_data),
      filename: "voice-#{message.to_param}.mp3",
      content_type: "audio/mpeg"
    )
  end

end
