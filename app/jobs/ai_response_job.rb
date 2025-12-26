class AiResponseJob < ApplicationJob

  include StreamsAiResponse

  def perform(chat)
    unless chat.is_a?(Chat)
      raise ArgumentError, "Expected a Chat object, got #{chat.class}: #{chat.inspect}"
    end

    @chat = chat
    @ai_message = nil
    setup_streaming_state

    chat.available_tools.each { |tool| chat = chat.with_tool(tool) }

    chat.on_new_message do
      @ai_message = chat.messages.order(:created_at).last
      @ai_message.update!(streaming: true) if @ai_message
    end

    chat.on_tool_call { |tc| handle_tool_call(tc) }
    chat.on_end_message { |msg| finalize_message!(msg) }

    chat.complete do |chunk|
      next unless chunk.content && @ai_message
      enqueue_stream_chunk(chunk.content)
    end
  rescue RubyLLM::ModelNotFoundError => e
    Rails.logger.error "Model not found: #{e.message}"
    RubyLLM.models.refresh!
    retry_job
  ensure
    cleanup_streaming
  end

end
