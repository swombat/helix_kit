# frozen_string_literal: true

class ManualAgentResponseJob < ApplicationJob

  include StreamsAiResponse
  include SelectsLlmProvider
  include BroadcastsDebug

  retry_on RubyLLM::ModelNotFoundError, wait: 5.seconds, attempts: 2
  retry_on RubyLLM::BadRequestError, wait: :polynomially_longer, attempts: 3
  retry_on RubyLLM::ServerError, wait: :polynomially_longer, attempts: 3
  retry_on RubyLLM::RateLimitError, wait: :polynomially_longer, attempts: 5
  retry_on Faraday::Error, wait: :polynomially_longer, attempts: 3

  def perform(chat, agent, initiation_reason: nil)
    @chat = chat
    @agent = agent
    @ai_message = nil
    setup_streaming_state

    debug_info "Starting response for agent '#{agent.name}' (model: #{agent.model_id})"

    @use_thinking = agent.uses_thinking? && Chat.supports_thinking?(agent.model_id)
    debug_info "Thinking: #{@use_thinking ? 'enabled' : 'disabled'}"

    provider_config = llm_provider_for(agent.model_id, thinking_enabled: @use_thinking)
    @provider = provider_config[:provider]

    if @use_thinking && Chat.requires_direct_api_for_thinking?(agent.model_id) && !anthropic_api_available?
      record_thinking_skip!("anthropic_key_unavailable",
        content: "_Extended thinking requires Anthropic API access, but the API key is not configured. Configure ANTHROPIC_API_KEY to enable signed reasoning blocks._")
      return
    end

    @pending_skip_reason = "tool_continuity_missing" if @use_thinking && @provider == :gemini && missing_gemini_tool_continuity?(chat, agent)

    context = chat.build_context_for_agent(agent, thinking_enabled: @use_thinking, provider: @provider, initiation_reason: initiation_reason)
    debug_info "Built context with #{context.length} messages"

    debug_info "Using provider: #{provider_config[:provider]}, model: #{provider_config[:model_id]}"

    llm = RubyLLM.chat(
      model: provider_config[:model_id],
      provider: provider_config[:provider],
      assume_model_exists: true
    )

    # Configure thinking if enabled and conversation is compatible
    if @use_thinking
      budget = agent.thinking_budget || 10000
      llm = configure_thinking(llm, budget, provider_config[:provider])
      debug_info "Configured thinking with budget: #{budget}"
    end

    # Tool setup
    tools_added = []
    agent.tools.each do |tool_class|
      tool = tool_class.new(chat: chat, current_agent: agent)
      next if tool.respond_to?(:available?) && !tool.available?
      llm = llm.with_tool(tool)
      tools_added << tool_class.name
    end
    debug_info "Added #{tools_added.length} tools: #{tools_added.join(', ')}" if tools_added.any?

    if chat.audio_tools_available_for?(agent.model_id)
      llm = llm.with_tool(FetchAudioTool.new(chat: chat, current_agent: agent))
      tools_added << "FetchAudioTool"
      debug_info "Added FetchAudioTool (model supports audio input, voice messages present)"
    end

    llm.on_new_message do
      if @ai_message
        # Reuse the existing message for the entire response cycle,
        # including tool call rounds. This prevents a single response
        # from being split across multiple message bubbles.
        debug_info "Reusing message #{@ai_message.obfuscated_id} for continued response"
        next
      end

      debug_info "Creating new assistant message"
      @ai_message = chat.messages.create!(
        role: "assistant",
        agent: agent,
        content: "",
        thinking: "",
        streaming: true
      )
      debug_info "Message created with ID: #{@ai_message.obfuscated_id}"
    end

    llm.on_tool_call do |tc|
      debug_info "Tool call: #{tc.name}(#{tc.arguments.to_json.truncate(100)})"
      handle_tool_call(tc)
    end

    llm.on_end_message do |msg|
      if msg.tool_call?
        @ai_message&.sync_tool_calls_from(msg)
        next
      end
      next if msg.tool_result?

      debug_info "Response complete - #{msg.content&.length || 0} chars"
      finalize_message!(msg)
      stamp_pending_skip_reason!
      @agent.notify_subscribers!(@ai_message, @chat) if @ai_message&.persisted? && initiation_reason.present?

      # Clear after finalize_message! succeeds -- if finalize raises, context survives for retry
      ChatAgent.find_by(chat: @chat, agent: @agent)&.clear_borrowed_context!
    end

    debug_info "Sending request to LLM..."
    start_time = Time.current
    context.each { |msg| llm.add_message(msg) }

    # In test environment, use sync mode (no streaming block) because VCR
    # doesn't support Faraday's on_data streaming callback. The callbacks
    # (on_new_message, on_end_message) still fire in sync mode.
    if Rails.env.test?
      llm.complete
    else
      llm.complete do |chunk|
        next unless @ai_message

        # Handle thinking chunks (RubyLLM now provides unified chunk.thinking)
        enqueue_thinking_chunk(chunk.thinking) if chunk.thinking.present?

        # Handle content chunks
        enqueue_stream_chunk(chunk.content) if chunk.content.present?
      end
    end

    elapsed = ((Time.current - start_time) * 1000).round
    debug_info "LLM request completed in #{elapsed}ms"
  rescue RubyLLM::ModelNotFoundError => e
    debug_error "Model not found: #{e.message}"
    RubyLLM.models.refresh!
    raise
  rescue RubyLLM::BadRequestError, RubyLLM::ServerError, RubyLLM::RateLimitError, RubyLLM::Error => e
    debug_error "API error: #{e.message}"
    broadcast_error("AI service error: #{e.message}")
    cleanup_partial_message
    raise
  rescue Faraday::Error => e
    debug_error "Network error: #{e.class.name} - #{e.message}"
    broadcast_error("Network error - please try again")
    cleanup_partial_message
    raise
  rescue TypeError, NoMethodError => e
    # RubyLLM's streaming error parser can crash when providers return
    # non-standard error formats (e.g., xAI uses flat {code, error} instead
    # of OpenAI's nested {error: {type, message}}). Treat as API error.
    debug_error "API error (parse failure): #{e.class.name} - #{e.message}"
    broadcast_error("AI service error - please try again")
    cleanup_partial_message
    raise
  rescue StandardError => e
    debug_error "Unexpected error: #{e.class.name} - #{e.message}"
    cleanup_partial_message
    raise
  ensure
    cleanup_streaming
  end

  private

  # Configures thinking on the LLM chat, with fallback for outdated model registry
  def configure_thinking(llm, budget, provider)
    # Anthropic requires max_tokens > budget_tokens, so we must set it explicitly
    if provider == :anthropic
      max_tokens = budget + 8000
      llm.with_thinking(budget: budget).with_params(max_tokens: max_tokens)
    else
      llm.with_thinking(budget: budget)
    end
  rescue StandardError => e
    raise unless unsupported_thinking_feature_error?(e)

    # Model registry may be outdated - fall back to direct params for known providers
    case provider
    when :anthropic
      max_tokens = budget + 8000
      llm.with_params(
        thinking: { type: "enabled", budget_tokens: budget },
        max_tokens: max_tokens
      )
    when :openrouter, :openai, :xai
      # OpenAI/xAI use reasoning effort levels (xAI Grok models support similar format)
      effort = budget_to_effort(budget)
      llm.with_params(
        reasoning: { effort: effort, summary: "auto" },
        max_completion_tokens: budget + 8000
      )
    else
      raise # Re-raise for truly unsupported models
    end
  end

  def unsupported_thinking_feature_error?(error)
    error.class.name == "RubyLLM::UnsupportedFeatureError"
  end

  # Converts token budget to OpenAI reasoning effort level
  def budget_to_effort(budget)
    case budget
    when 0..2000 then "low"
    when 2001..15000 then "medium"
    else "high"
    end
  end

  def record_thinking_skip!(reason, content:)
    debug_info "Recording reasoning skip: #{reason}"
    @ai_message ||= @chat.messages.create!(role: "assistant", agent: @agent, content: content)
    @ai_message.update!(reasoning_skip_reason: reason)
    @message_finalized = true
  end

  def missing_gemini_tool_continuity?(chat, agent)
    chat.messages.where(agent_id: agent.id).joins(:tool_calls)
        .where("tool_calls.replay_payload IS NULL OR NOT (tool_calls.replay_payload ? 'thought_signature')")
        .exists?
  end

  def stamp_pending_skip_reason!
    return unless @pending_skip_reason && @ai_message&.persisted?
    @ai_message.update_columns(reasoning_skip_reason: @pending_skip_reason)
    @pending_skip_reason = nil
  end

  def broadcast_error(message)
    ActionCable.server.broadcast(
      "Chat:#{@chat.to_param}",
      { action: "error", message: message }
    )
  end

end
