class AllAgentsResponseJob < ApplicationJob

  include StreamsAiResponse
  include SelectsLlmProvider

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

    context = chat.build_context_for_agent(agent)

    provider_config = llm_provider_for(agent.model_id)
    llm = RubyLLM.chat(
      model: provider_config[:model_id],
      provider: provider_config[:provider],
      assume_model_exists: true
    )

    agent.tools.each do |tool_class|
      tool = tool_class.new(chat: chat, current_agent: agent)
      llm = llm.with_tool(tool)
    end

    llm.on_new_message do
      @ai_message = chat.messages.create!(
        role: "assistant",
        agent: agent,
        content: "",
        streaming: true
      )
    end

    llm.on_tool_call { |tc| handle_tool_call(tc) }
    llm.on_end_message { |msg| finalize_message!(msg) }

    # Add context messages individually, then complete
    # This ensures the tool call loop continues until a final text response
    context.each { |msg| llm.add_message(msg) }
    llm.complete do |chunk|
      next unless chunk.content && @ai_message
      enqueue_stream_chunk(chunk.content)
    end

    # Queue the next agent after this one completes
    if remaining_agent_ids.any?
      AllAgentsResponseJob.perform_later(chat, remaining_agent_ids)
    end
  rescue RubyLLM::ModelNotFoundError => e
    Rails.logger.error "Model not found: #{e.message}"
    RubyLLM.models.refresh!
    raise # Let retry_on handle it
  rescue RubyLLM::BadRequestError, RubyLLM::ServerError, RubyLLM::RateLimitError, Faraday::Error => e
    Rails.logger.error "LLM provider error for agent #{agent&.name}: #{e.message}"
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
