# frozen_string_literal: true

module ConfiguresLlmThinking

  extend ActiveSupport::Concern

  private

  def configure_thinking(llm, budget, provider)
    if provider == :anthropic
      max_tokens = budget + 8000
      llm.with_thinking(budget: budget).with_params(max_tokens: max_tokens)
    elsif provider == :openai
      llm.with_thinking(effort: budget_to_effort(budget))
    else
      llm.with_thinking(budget: budget)
    end
  rescue StandardError => e
    raise unless unsupported_thinking_feature_error?(e)

    case provider
    when :anthropic
      max_tokens = budget + 8000
      llm.with_params(
        thinking: { type: "enabled", budget_tokens: budget },
        max_tokens: max_tokens
      )
    when :openrouter, :openai, :xai
      effort = budget_to_effort(budget)
      llm.with_params(
        reasoning: { effort: effort, summary: "auto" },
        max_completion_tokens: budget + 8000
      )
    else
      raise
    end
  end

  def ensure_tool_compatible_thinking(llm, provider_config, tools_added)
    return llm if tools_added.empty?
    return llm unless provider_config[:provider] == :openai
    return llm unless provider_config[:model_id] == "gpt-5.6-sol"

    # OpenAI's Chat Completions endpoint rejects Sol requests that combine
    # function tools with its default reasoning effort, even when thinking was
    # not explicitly enabled. Keep tools available until this path moves to the
    # Responses API, and only record a skip when reasoning was requested.
    @pending_skip_reason ||= "provider_unsupported" if @use_thinking
    debug_info "Set reasoning effort to 'none': gpt-5.6-sol tools require it on Chat Completions"
    llm.with_thinking(effort: "none")
  end

  def unsupported_thinking_feature_error?(error)
    error.class.name == "RubyLLM::UnsupportedFeatureError"
  end

  def budget_to_effort(budget)
    case budget
    when 0..2000 then "low"
    when 2001..15000 then "medium"
    else "high"
    end
  end

end
