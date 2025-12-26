class ManualAgentResponseJob < ApplicationJob

  include StreamsAiResponse

  def perform(chat, agent)
    @chat = chat
    @agent = agent
    @ai_message = nil
    setup_streaming_state

    context = chat.build_context_for_agent(agent)

    llm = RubyLLM.chat(
      model: agent.model_id,
      provider: :openrouter,
      assume_model_exists: true
    )

    agent.tools.each { |tool| llm = llm.with_tool(tool) }

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

    llm.ask(context) do |chunk|
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
