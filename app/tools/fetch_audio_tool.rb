class FetchAudioTool < RubyLLM::Tool

  description "Fetch the original audio recording for a voice message. " \
              "Returns the audio file so you can hear the user's actual voice, tone, and inflection. " \
              "Use the message_id shown in the conversation context."

  param :message_id, type: :string,
        desc: "The obfuscated ID of the message with the audio recording",
        required: true

  def initialize(chat: nil, current_agent: nil)
    super()
    @chat = chat
    @current_agent = current_agent
  end

  def execute(message_id:)
    return { error: "No chat context" } unless @chat

    message = @chat.messages.find_by(id: Message.decode_id(message_id))
    return { error: "Message not found in this conversation" } unless message
    return { error: "This message has no audio recording" } unless message.audio_recording.attached?

    audio_path = message.audio_path_for_llm
    return { error: "Audio file unavailable" } unless audio_path

    RubyLLM::Content.new(
      "Audio recording from #{message.author_name} at #{message.created_at_formatted}",
      [ audio_path ]
    )
  end

end
