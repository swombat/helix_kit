class GenerateTitleJob < ApplicationJob

  def perform(chat)
    return if chat.title.present?

    first_message = chat.messages.find_by(role: "user")
    return unless first_message

    title = chat.generate_title(first_message.content)
    chat.update!(title: title) if title.present?
  end

end
