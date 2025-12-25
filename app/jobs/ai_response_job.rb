class AiResponseJob < ApplicationJob

  STREAM_DEBOUNCE_INTERVAL = 0.2.seconds

  def perform(chat)
    # Ensure we got a single chat object, not a relation
    unless chat.is_a?(Chat)
      raise ArgumentError, "Expected a Chat object, got #{chat.class}: #{chat.inspect}"
    end

    @chat = chat
    @ai_message = nil
    @stream_buffer = +""
    @last_stream_flush_at = nil
    @tools_used = []

    # Configure tools from chat settings
    chat.available_tools.each { |tool| chat = chat.with_tool(tool) }

    chat.on_new_message do
      @ai_message = chat.messages.order(:created_at).last
      # Set streaming to true so "Generating response..." shows
      @ai_message.update!(streaming: true) if @ai_message
    end

    # Track tool invocations
    chat.on_tool_call do |tool_call|
      # Extract URL for web fetches, otherwise use tool name
      url = tool_call.arguments[:url] || tool_call.arguments["url"]
      @tools_used << (url || tool_call.name.to_s)
      Rails.logger.info "Tool invoked: #{tool_call.name} with args: #{tool_call.arguments}"
    end

    chat.on_end_message do |ruby_llm_message|
      finalize_message!(ruby_llm_message)
    end

    chat.complete do |chunk|
      next unless chunk.content && @ai_message
      enqueue_stream_chunk(chunk.content)
    end
  rescue RubyLLM::ModelNotFoundError => e
    @model_not_found_error = true
    error "Model not found: #{e.message}, trying again..."
    RubyLLM.models.refresh!
    self.retry_job unless @model_not_found_error
  ensure
    flush_stream_buffer(force: true)
    # Ensure streaming is stopped even if job fails
    @ai_message&.stop_streaming if @ai_message&.streaming?
  end

  private

  def finalize_message!(ruby_llm_message)
    @ai_message ||= @chat.messages.order(:created_at).last

    return unless @ai_message

    flush_stream_buffer(force: true)

    @ai_message.update!({
      content: extract_message_content(ruby_llm_message.content),
      model_id: ruby_llm_message.model_id,
      input_tokens: ruby_llm_message.input_tokens,
      output_tokens: ruby_llm_message.output_tokens,
      tools_used: @tools_used.uniq,
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

  def enqueue_stream_chunk(chunk_content)
    @stream_buffer << chunk_content.to_s
    flush_stream_buffer if stream_flush_due?
  end

  def flush_stream_buffer(force: false)
    return if @stream_buffer.blank?
    return unless @ai_message
    return unless force || stream_flush_due?

    chunk = @stream_buffer
    @stream_buffer = +""
    @last_stream_flush_at = Time.current
    @ai_message.stream_content(chunk)
  end

  def stream_flush_due?
    return true unless @last_stream_flush_at

    Time.current - @last_stream_flush_at >= STREAM_DEBOUNCE_INTERVAL
  end

end
