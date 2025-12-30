module StreamsAiResponse

  extend ActiveSupport::Concern

  STREAM_DEBOUNCE_INTERVAL = 0.2.seconds

  private

  def setup_streaming_state
    @stream_buffer = +""
    @last_stream_flush_at = nil
    @tools_used = []
  end

  def finalize_message!(ruby_llm_message)
    return unless @ai_message

    flush_stream_buffer(force: true)

    # Update message content and metadata (streaming state is handled by stop_streaming in cleanup)
    @ai_message.update!({
      content: extract_message_content(ruby_llm_message.content),
      model_id_string: ruby_llm_message.model_id,
      input_tokens: ruby_llm_message.input_tokens,
      output_tokens: ruby_llm_message.output_tokens,
      tools_used: @tools_used.uniq
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

  # Tools that shouldn't show status updates (e.g., "Using view system prompt tool...")
  # They still appear in tools_used badges
  QUIET_TOOLS = %w[
    ViewSystemPromptTool view_system_prompt
    UpdateSystemPromptTool update_system_prompt
  ].freeze

  def handle_tool_call(tool_call)
    tool_name = tool_call.name.to_s
    Rails.logger.info "Tool invoked: #{tool_name} with args: #{tool_call.arguments}"

    url = tool_call.arguments[:url] || tool_call.arguments["url"]
    @tools_used << (url || tool_name)

    # Skip status broadcast for quiet tools (but they still get badges)
    return if QUIET_TOOLS.include?(tool_name)

    @ai_message&.broadcast_tool_call(
      tool_name: tool_name,
      tool_args: tool_call.arguments
    )
  end

  def cleanup_streaming
    flush_stream_buffer(force: true)
    @ai_message&.stop_streaming if @ai_message&.streaming?
  end

end
