# frozen_string_literal: true

module StreamsAiResponse

  extend ActiveSupport::Concern

  CONTENT_DEBOUNCE = 0.2.seconds
  THINKING_DEBOUNCE = 0.1.seconds

  private

  def setup_streaming_state
    @content_buffer = +""
    @content_accumulated = +""
    @content_last_flush_at = nil

    @thinking_buffer = +""
    @thinking_accumulated = +""
    @thinking_last_flush_at = nil

    @tools_used = []
  end

  def finalize_message!(ruby_llm_message)
    return unless @ai_message

    flush_all_buffers

    # Use RubyLLM's thinking attribute (authoritative source) with buffer fallback
    thinking_content = ruby_llm_message.thinking.presence || @thinking_accumulated.presence

    # Use RubyLLM's content with fallback to accumulated streaming content or existing DB content
    # This prevents the update! from overwriting content that was already saved during streaming
    content = extract_message_content(ruby_llm_message.content)
    if content.blank?
      # First try accumulated content (in-memory copy of what was streamed)
      # Then fall back to what's already in the database (which was saved during streaming)
      fallback_content = @content_accumulated.presence || @ai_message.reload.content
      if fallback_content.present?
        Rails.logger.warn "⚠️ RubyLLM content was blank, using fallback content (#{fallback_content.length} chars)"
        content = fallback_content
      end
    end

    # Check for empty response which may indicate content filtering
    if content.blank? && ruby_llm_message.output_tokens.to_i == 0
      Rails.logger.warn "⚠️ LLM returned empty response (0 output tokens)"
      Rails.logger.warn "⚠️ Raw response: #{ruby_llm_message.raw.inspect}"

      # Check for Gemini-specific block reasons in the raw response
      # raw might be a Faraday::Response or a Hash depending on the provider
      raw = ruby_llm_message.raw
      raw = raw.is_a?(Hash) ? raw : {}

      finish_reason = raw.dig("candidates", 0, "finishReason") ||
                      raw.dig("choices", 0, "finish_reason")
      block_reason = raw.dig("promptFeedback", "blockReason") ||
                     raw.dig("candidates", 0, "finishReason")

      if block_reason == "SAFETY" || finish_reason == "SAFETY"
        Rails.logger.warn "⚠️ Response blocked due to safety filters"
        content = "_The AI was unable to respond due to content safety filters. Try rephrasing your message or starting a new conversation._"
      elsif finish_reason.present? && finish_reason != "STOP"
        Rails.logger.warn "⚠️ Unusual finish reason: #{finish_reason}"
        content = "_The AI was unable to complete its response (reason: #{finish_reason}). Please try again._"
      else
        content = "_The AI returned an empty response. This may be due to content filtering or a temporary issue. Please try again._"
      end
    end

    @ai_message.update!({
      content: content,
      thinking: thinking_content,
      model_id_string: ruby_llm_message.model_id,
      input_tokens: ruby_llm_message.input_tokens,
      output_tokens: ruby_llm_message.output_tokens,
      tools_used: @tools_used.uniq
    })

    # Queue content moderation for the completed assistant message
    ModerateMessageJob.perform_later(@ai_message) if @ai_message.content.present?
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

  def enqueue_stream_chunk(chunk)
    @content_buffer << chunk.to_s
    @content_accumulated << chunk.to_s

    if content_flush_due?
      chunk_to_send = @content_buffer
      @content_buffer = +""
      @content_last_flush_at = Time.current
      @ai_message&.stream_content(chunk_to_send)
    end
  end

  def enqueue_thinking_chunk(chunk)
    @thinking_buffer << chunk.to_s
    @thinking_accumulated << chunk.to_s

    if thinking_flush_due?
      chunk_to_send = @thinking_buffer
      @thinking_buffer = +""
      @thinking_last_flush_at = Time.current
      @ai_message&.stream_thinking(chunk_to_send)
    end
  end

  def content_flush_due?
    @content_buffer.present? &&
      (@content_last_flush_at.nil? || Time.current - @content_last_flush_at >= CONTENT_DEBOUNCE)
  end

  def thinking_flush_due?
    @thinking_buffer.present? &&
      (@thinking_last_flush_at.nil? || Time.current - @thinking_last_flush_at >= THINKING_DEBOUNCE)
  end

  def flush_all_buffers
    if @content_buffer.present?
      @ai_message&.stream_content(@content_buffer)
      @content_buffer = +""
    end

    if @thinking_buffer.present?
      @ai_message&.stream_thinking(@thinking_buffer)
      @thinking_buffer = +""
    end
  end

  QUIET_TOOLS = %w[
    ViewSystemPromptTool view_system_prompt
    UpdateSystemPromptTool update_system_prompt
  ].freeze

  def handle_tool_call(tool_call)
    tool_name = tool_call.name.to_s
    Rails.logger.info "Tool invoked: #{tool_name} with args: #{tool_call.arguments}"

    url = tool_call.arguments[:url] || tool_call.arguments["url"]
    @tools_used << (url || tool_name)

    return if QUIET_TOOLS.include?(tool_name)

    @ai_message&.broadcast_tool_call(
      tool_name: tool_name,
      tool_args: tool_call.arguments
    )
  end

  def cleanup_streaming
    Rails.logger.info "🧹 cleanup_streaming called, @ai_message: #{@ai_message&.to_param || 'nil'}, streaming: #{@ai_message&.streaming?}"
    flush_all_buffers
    @ai_message&.stop_streaming if @ai_message&.streaming?
    Rails.logger.info "🧹 cleanup_streaming completed"
  end

end
