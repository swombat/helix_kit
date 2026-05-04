# frozen_string_literal: true

class PostMessageTool < ApplicationMCPTool

  tool_name "post_message"
  description "Post a message into a HelixKit chat as the authenticated API key user."
  destructive

  property :chat_id, type: "string",
    description: "The chat identifier from the URL.",
    required: true

  property :content, type: "string",
    description: "Message body. Markdown is supported.",
    required: true

  def perform
    user = current_user
    chat = Chat.accessible_by(user).find_by_obfuscated_id(chat_id)

    unless chat&.respondable?
      report_error("Chat not found or cannot receive messages")
      return
    end

    message = Current.set(api_user: user) do
      chat.messages.create!(user: user, role: "user", content: content)
    end

    render(text: "Posted message #{message.to_param} into chat #{chat.to_param}")
  rescue ActiveRecord::RecordInvalid => e
    report_error("Message could not be posted: #{e.record.errors.full_messages.to_sentence}")
  end

end
