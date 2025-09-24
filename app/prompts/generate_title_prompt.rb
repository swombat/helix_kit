# frozen_string_literal: true

class GenerateTitlePrompt < Prompt
  MAX_MESSAGES = 12
  MAX_MESSAGE_LENGTH = 240

  def initialize(chat:, model: Prompt::LIGHT_MODEL)
    super(model: model, template: "generate_title")
    @chat = chat
  end

  def generate_title
    response = execute_to_string
    extract_title(response)&.squish
  end

  private

  attr_reader :chat

  def render(**args)
    conversation_lines = build_conversation_lines

    super(**{ messages: conversation_lines }.merge(args))
  end

  def build_conversation_lines
    chat.messages
        .order(:created_at)
        .limit(MAX_MESSAGES)
        .map { |message| format_message_line(message) }
        .compact
  end

  def format_message_line(message)
    content = message.content.to_s.strip
    return if content.blank?

    label = case message.role
    when "user" then "User"
    when "assistant" then "Assistant"
    when "system" then "System"
    else
      message.role.to_s.titleize
    end

    truncated_content = content.truncate(MAX_MESSAGE_LENGTH)
    "#{label}: #{truncated_content}"
  end

  def extract_title(response)
    return if response.blank?

    if response.is_a?(Hash)
      response.dig("choices", 0, "message", "content")
    else
      response
    end
  end
end
