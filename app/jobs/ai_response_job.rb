class AiResponseJob < ApplicationJob

  def perform(chat, _user_message)
    ai_message = nil

    chat.on_new_message do
      ai_message = chat.messages.order(:created_at).last
    end

    chat.on_end_message do |message|
      ai_message ||= chat.messages.order(:created_at).last
      next unless ai_message

      finalize_message!(ai_message, message)
    end

    chat.complete do |chunk|
      next unless chunk.content

      ai_message ||= chat.messages.order(:created_at).last
      next unless ai_message

      ai_message.update_column(:content, ai_message.content.to_s + chunk.content)
      ai_message.broadcast_refresh if ai_message.respond_to?(:broadcast_refresh)
    end
  end

  private

  def finalize_message!(ai_message, ruby_llm_message)
    attributes = {
      content: extract_message_content(ruby_llm_message.content),
      model_id: ruby_llm_message.model_id,
      input_tokens: ruby_llm_message.input_tokens,
      output_tokens: ruby_llm_message.output_tokens
    }

    ai_message.update!(attributes.compact)
    ai_message.broadcast_refresh if ai_message.respond_to?(:broadcast_refresh)
  end

  def extract_message_content(content)
    case content
    when RubyLLM::Content
      content.text
    when Hash, Array
      content.to_json
    else
      content
    end
  end

end
