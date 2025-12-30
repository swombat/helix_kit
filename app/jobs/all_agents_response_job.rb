class AllAgentsResponseJob < ApplicationJob

  include StreamsAiResponse
  include SelectsLlmProvider
  include BroadcastsDebug

  # Retry on provider errors with exponential backoff (5s, 25s, 125s)
  retry_on RubyLLM::ModelNotFoundError, wait: 5.seconds, attempts: 2
  retry_on RubyLLM::BadRequestError, wait: :polynomially_longer, attempts: 3
  retry_on RubyLLM::ServerError, wait: :polynomially_longer, attempts: 3
  retry_on RubyLLM::RateLimitError, wait: :polynomially_longer, attempts: 5
  retry_on Faraday::Error, wait: :polynomially_longer, attempts: 3

  # Processes all agents in sequence by running the first agent and then
  # re-enqueueing itself with the remaining agents
  def perform(chat, agent_ids)
    return if agent_ids.empty?

    agent_id = agent_ids.first
    remaining_agent_ids = agent_ids.drop(1)

    agent = chat.agents.find(agent_id)

    # Process this agent (same logic as ManualAgentResponseJob)
    @chat = chat
    @agent = agent
    @ai_message = nil
    setup_streaming_state

    debug_info "Starting response for agent '#{agent.name}' (model: #{agent.model_id})"

    context = chat.build_context_for_agent(agent)
    debug_info "Built context with #{context.length} messages"
    context.each_with_index do |msg, i|
      content_preview = msg[:content].is_a?(String) ? msg[:content].truncate(100) : msg[:content].class.name
      debug_info "  [#{i}] #{msg[:role]}: #{content_preview}"
    end

    provider_config = llm_provider_for(agent.model_id)
    debug_info "Using provider: #{provider_config[:provider]}, model: #{provider_config[:model_id]}"

    llm = RubyLLM.chat(
      model: provider_config[:model_id],
      provider: provider_config[:provider],
      assume_model_exists: true
    )

    tools_added = []
    agent.tools.each do |tool_class|
      tool = tool_class.new(chat: chat, current_agent: agent)
      llm = llm.with_tool(tool)
      tools_added << tool_class.name
    end
    debug_info "Added #{tools_added.length} tools: #{tools_added.join(', ')}" if tools_added.any?

    llm.on_new_message do
      debug_info "Creating new assistant message"
      @ai_message = chat.messages.create!(
        role: "assistant",
        agent: agent,
        content: "",
        streaming: true
      )
      debug_info "Message created with ID: #{@ai_message.obfuscated_id}"
    end

    llm.on_tool_call do |tc|
      debug_info "Tool call: #{tc.name}(#{tc.arguments.to_json.truncate(100)})"
      handle_tool_call(tc)
    end

    llm.on_end_message do |msg|
      debug_info "Response complete - #{msg.content&.length || 0} chars, #{msg.input_tokens || 0} input / #{msg.output_tokens || 0} output tokens"
      finalize_message!(msg)
    end

    # Add context messages individually, then complete
    # This ensures the tool call loop continues until a final text response
    debug_info "Sending request to LLM..."
    start_time = Time.current
    context.each { |msg| llm.add_message(msg) }
    llm.complete do |chunk|
      next unless chunk.content && @ai_message
      enqueue_stream_chunk(chunk.content)
    end
    elapsed = ((Time.current - start_time) * 1000).round
    debug_info "LLM request completed in #{elapsed}ms"

    # Queue the next agent after this one completes
    if remaining_agent_ids.any?
      debug_info "Queuing next agent (#{remaining_agent_ids.length} remaining)"
      AllAgentsResponseJob.perform_later(chat, remaining_agent_ids)
    end
  rescue RubyLLM::ModelNotFoundError => e
    debug_error "Model not found: #{e.message}"
    RubyLLM.models.refresh!
    raise # Let retry_on handle it
  rescue RubyLLM::BadRequestError => e
    debug_error "Bad request error: #{e.message}"
    cleanup_partial_message
    raise # Let retry_on handle it
  rescue RubyLLM::ServerError => e
    debug_error "Server error: #{e.message}"
    cleanup_partial_message
    raise # Let retry_on handle it
  rescue RubyLLM::RateLimitError => e
    debug_error "Rate limit error: #{e.message}"
    cleanup_partial_message
    raise # Let retry_on handle it
  rescue Faraday::Error => e
    debug_error "Network error: #{e.class.name} - #{e.message}"
    cleanup_partial_message
    raise # Let retry_on handle it
  rescue StandardError => e
    debug_error "Unexpected error: #{e.class.name} - #{e.message}"
    raise
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
