class Messages::VoicesController < Messages::BaseController

  def create
    unless @message.voice_available
      render json: { error: "Voice not available for this message" }, status: :unprocessable_entity
      return
    end

    if @message.voice_audio.attached?
      render json: { voice_audio_url: @message.voice_audio_url }
    else
      GenerateVoiceJob.perform_later(@message)
      head :accepted
    end
  end

end
