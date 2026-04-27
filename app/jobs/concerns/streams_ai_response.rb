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
    @message_finalized = false
  end

  def finalize_message!(ruby_llm_message)
    return unless @ai_message

    flush_all_buffers

    if rlm_content_blank?(ruby_llm_message)
      composed = compose_finalized_content(ruby_llm_message)
      @ai_message.content = composed if composed.present?
    end

    @ai_message.record_provider_response!(ruby_llm_message, provider: @provider, tool_names: @tools_used)

    deduplicate_message!
    @message_finalized = true

    ModerateMessageJob.perform_later(@ai_message)         if @ai_message.content.present?
    FixHallucinatedToolCallsJob.perform_later(@ai_message) if @ai_message.fixable
  end

  def rlm_content_blank?(rlm)
    extract_message_content(rlm.content).to_s.strip.empty?
  end

  def compose_finalized_content(rlm)
    raw = extract_message_content(rlm.content)
    return raw if raw.present?

    fallback = @content_accumulated.presence || @ai_message.reload.content
    return fallback if fallback.present?

    empty_response_fallback(rlm)
  end

  def empty_response_fallback(rlm)
    return nil if rlm.output_tokens.to_i > 0

    raw = rlm.raw.is_a?(Hash) ? rlm.raw : {}
    finish_reason = raw.dig("candidates", 0, "finishReason") || raw.dig("choices", 0, "finish_reason")
    block_reason  = raw.dig("promptFeedback", "blockReason") || finish_reason

    if block_reason == "SAFETY" || finish_reason == "SAFETY"
      "_The AI was unable to respond due to content safety filters. Try rephrasing your message or starting a new conversation._"
    elsif finish_reason.present? && finish_reason != "STOP"
      "_The AI was unable to complete its response (reason: #{finish_reason}). Please try again._"
    else
      "_The AI returned an empty response. This may be due to content filtering or a temporary issue. Please try again._"
    end
  end

  # After tool use, models often repeat the same text in a new message.
  # When we detect an identical previous message from the same agent,
  # merge tools_used into the earlier message and destroy the duplicate.
  def deduplicate_message!
    return if @ai_message.blank? || @ai_message.content.blank?

    previous = Message.where(
      chat_id: @ai_message.chat_id,
      role: "assistant",
      agent_id: @ai_message.agent_id,
      content: @ai_message.content
    ).where("id < ?", @ai_message.id)
     .order(id: :desc)
     .first

    return unless previous

    previous.update!(tools_used: (Array(previous.tools_used) + Array(@ai_message.tools_used)).uniq)

    Rails.logger.info "🔄 Deduplicated message #{@ai_message.id} (merged into #{previous.id})"
    @ai_message.destroy!
    @ai_message = previous
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
    text = (chunk.respond_to?(:text) ? chunk.text : chunk).to_s
    @thinking_buffer << text
    @thinking_accumulated << text

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

  # Destroy the current message if it was never properly finalized.
  # Called from error handlers before the job retries, so the retry
  # starts fresh instead of leaving orphaned partial messages.
  def cleanup_partial_message
    return unless @ai_message&.persisted?
    return if @message_finalized

    Rails.logger.info "🧹 Destroying un-finalized message #{@ai_message.id}"
    @ai_message.destroy
    @ai_message = nil
  end

  def cleanup_streaming
    Rails.logger.info "🧹 cleanup_streaming called, @ai_message: #{@ai_message&.to_param || 'nil'}, streaming: #{@ai_message&.streaming?}"
    flush_all_buffers
    @ai_message&.stop_streaming if @ai_message&.persisted? && @ai_message&.streaming?
    Rails.logger.info "🧹 cleanup_streaming completed"
  end

end
