class AiResponseJob < ApplicationJob

  def perform(chat)
    @ai_message = nil

    chat.on_new_message do
      @ai_message = chat.messages.order(:created_at).last
    end

    chat.on_end_message do |ruby_llm_message|
      finalize_message!(ruby_llm_message)
    end

    chat.complete do |chunk|
      next unless chunk.content && @ai_message

      # Stream the content update
      @ai_message.stream_content(chunk.content)
    end
  ensure
    # Ensure streaming is stopped even if job fails
    @ai_message&.stop_streaming! if @ai_message&.streaming?
  end

  private

  def finalize_message!(ruby_llm_message)
    @ai_message ||= chat.messages.order(:created_at).last

    return unless @ai_message

    @ai_message.update!({
      content: extract_message_content(ruby_llm_message.content),
      model_id: ruby_llm_message.model_id,
      input_tokens: ruby_llm_message.input_tokens,
      output_tokens: ruby_llm_message.output_tokens,
      streaming: false
    })
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
