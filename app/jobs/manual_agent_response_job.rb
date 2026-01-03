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

  def perform(chat, agent)
    @chat = chat
    @agent = agent
    @ai_message = nil
    setup_streaming_state

    debug_info "Starting response for agent '#{agent.name}' (model: #{agent.model_id})"
    debug_info "Thinking: #{agent.uses_thinking? ? 'enabled' : 'disabled'}"

    # Check for missing API key upfront for thinking-enabled agents
    if agent.uses_thinking? && Chat.requires_direct_api_for_thinking?(agent.model_id) && !anthropic_api_available?
      broadcast_error("Extended thinking requires Anthropic API access, but the API key is not configured.")
      return
    end

    context = chat.build_context_for_agent(agent)
    debug_info "Built context with #{context.length} messages"

    provider_config = llm_provider_for(agent.model_id, thinking_enabled: agent.uses_thinking?)
    debug_info "Using provider: #{provider_config[:provider]}, model: #{provider_config[:model_id]}"

    llm = RubyLLM.chat(
      model: provider_config[:model_id],
      provider: provider_config[:provider],
      assume_model_exists: true
    )

    # Configure thinking if enabled for this agent
    if agent.uses_thinking?
      budget = agent.thinking_budget || 10000
      llm = configure_thinking(llm, budget, provider_config[:provider])
      debug_info "Configured thinking with budget: #{budget}"
    end

    # Tool setup
    tools_added = []
    agent.tools.each do |tool_class|
      tool = tool_class.new(chat: chat, current_agent: agent)
      llm = llm.with_tool(tool)
      tools_added << tool_class.name
    end
    debug_info "Added #{tools_added.length} tools: #{tools_added.join(', ')}" if tools_added.any?

    llm.on_new_message do
      @ai_message&.stop_streaming if @ai_message&.streaming?

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
      debug_info "Response complete - #{msg.content&.length || 0} chars"
      finalize_message!(msg)
    end

    debug_info "Sending request to LLM..."
    start_time = Time.current
    context.each { |msg| llm.add_message(msg) }

    llm.complete do |chunk|
      next unless @ai_message

      # Handle thinking chunks (RubyLLM now provides unified chunk.thinking)
      enqueue_thinking_chunk(chunk.thinking) if chunk.thinking.present?

      # Handle content chunks
      enqueue_stream_chunk(chunk.content) if chunk.content.present?
    end

    elapsed = ((Time.current - start_time) * 1000).round
    debug_info "LLM request completed in #{elapsed}ms"
  rescue RubyLLM::ModelNotFoundError => e
    debug_error "Model not found: #{e.message}"
    RubyLLM.models.refresh!
    raise
  rescue RubyLLM::BadRequestError, RubyLLM::ServerError, RubyLLM::RateLimitError => e
    debug_error "API error: #{e.message}"
    broadcast_error("AI service error: #{e.message}")
    cleanup_partial_message
    raise
  rescue Faraday::Error => e
    debug_error "Network error: #{e.class.name} - #{e.message}"
    broadcast_error("Network error - please try again")
    cleanup_partial_message
    raise
  rescue StandardError => e
    debug_error "Unexpected error: #{e.class.name} - #{e.message}"
    raise
  ensure
    cleanup_streaming
  end

  private

  # Configures thinking on the LLM chat, with fallback for outdated model registry
  def configure_thinking(llm, budget, provider)
    llm.with_thinking(budget: budget)
  rescue RubyLLM::UnsupportedFeatureError
    # Model registry may be outdated - fall back to direct params for known providers
    case provider
    when :anthropic
      max_tokens = budget + 8000
      llm.with_params(
        thinking: { type: "enabled", budget_tokens: budget },
        max_tokens: max_tokens
      )
    else
      raise # Re-raise for truly unsupported models
    end
  end

  def broadcast_error(message)
    @chat.broadcast_marker(
      "Chat:#{@chat.to_param}",
      { action: "error", message: message }
    )
  end

  def cleanup_partial_message
    return unless @ai_message&.persisted?
    @ai_message.destroy if @ai_message.content.blank? && @ai_message.streaming?
  end

end
