class AiResponseJob < ApplicationJob

  def perform(chat, user_message)
    ai_message = chat.messages.build(role: "assistant", content: "")
    ai_message.save!(validate: false) # Skip validation for empty initial content

    chat.ask(user_message.content) do |chunk|
      if chunk.content
        ai_message.update_column(:content, ai_message.content + chunk.content)
        ai_message.broadcast_refresh if ai_message.respond_to?(:broadcast_refresh)
      end
    end
  end

end
