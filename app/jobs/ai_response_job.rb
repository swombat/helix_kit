class AiResponseJob < ApplicationJob

  include StreamsAiResponse

  # Retry on provider errors with exponential backoff (5s, 25s, 125s)
  retry_on RubyLLM::ModelNotFoundError, wait: 5.seconds, attempts: 2
  retry_on RubyLLM::BadRequestError, wait: :polynomially_longer, attempts: 3
  retry_on RubyLLM::ServerError, wait: :polynomially_longer, attempts: 3
  retry_on RubyLLM::RateLimitError, wait: :polynomially_longer, attempts: 5
  retry_on Faraday::Error, wait: :polynomially_longer, attempts: 3

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
    raise # Let retry_on handle it
  rescue RubyLLM::BadRequestError, RubyLLM::ServerError, RubyLLM::RateLimitError, Faraday::Error => e
    Rails.logger.error "LLM provider error: #{e.message}"
    cleanup_partial_message
    raise # Let retry_on handle it
  ensure
    cleanup_streaming
  end

  private

  def cleanup_partial_message
    return unless @ai_message&.persisted?
    # Delete empty streaming messages that were created before the error
    @ai_message.destroy if @ai_message.content.blank? && @ai_message.streaming?
  end

end
