class Chats::TranscriptionsController < ApplicationController

  include ChatScoped

  before_action :require_respondable_chat

  def create
    audio = params.require(:audio)
    text = ElevenLabsStt.transcribe(audio)

    if text.present?
      render json: { text: text }
    else
      render json: { error: "No speech detected" }, status: :unprocessable_entity
    end
  rescue ElevenLabsStt::Error => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

end
