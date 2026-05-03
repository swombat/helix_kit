module Message::Replayable

  extend ActiveSupport::Concern

  REASONING_SKIP_REASONS = {
    "legacy_no_signature"        => "Thinking unavailable: this turn was created before signed thinking blocks were stored.",
    "tool_continuity_missing"    => "Thinking degraded: an earlier tool call is missing continuity metadata.",
    "provider_unsupported"       => "Thinking unavailable for this turn.",
    "anthropic_key_unavailable"  => "Thinking unavailable: Anthropic API key not configured."
  }.freeze

  def reasoning_skip_reason
    self[:reasoning_skip_reason] || inferred_skip_reason
  end

  def reasoning_skip_reason_label
    REASONING_SKIP_REASONS[reasoning_skip_reason]
  end

  def thinking_signature
    replay_payload&.dig("thinking", "signature")
  end

  def record_provider_response!(ruby_llm_message, provider: nil, tool_names: [])
    update!(
      content:               extract_provider_content(ruby_llm_message) || content,
      thinking_text:         provider_thinking_text(ruby_llm_message),
      thinking_tokens:       ruby_llm_message.thinking_tokens,
      input_tokens:          ruby_llm_message.input_tokens,
      output_tokens:         ruby_llm_message.output_tokens,
      cached_tokens:         extract_cached_tokens(ruby_llm_message),
      cache_creation_tokens: extract_cache_creation_tokens(ruby_llm_message),
      model_id_string:       ruby_llm_message.model_id || model_id_string,
      replay_payload:        build_replay_payload(ruby_llm_message, provider),
      tools_used:            tool_names.uniq.presence || tools_used
    )
    sync_tool_calls_from(ruby_llm_message)
    self
  end

  def sync_tool_calls_from(ruby_llm_message)
    Array(ruby_llm_message.tool_calls).each do |tc|
      tc_id, tc_obj = tc.is_a?(Array) ? tc : [ tc.id, tc ]
      tool_calls.find_or_create_by!(tool_call_id: tc_id) do |row|
        row.name           = tc_obj.name
        row.arguments      = tc_obj.arguments
        row.replay_payload = gemini_thought_signature_payload(tc_obj)
      end
    end
  end

  def replay_for(provider, current_agent:)
    return user_shaped_replay(current_agent) if agent_id != current_agent.id

    case provider
    when :anthropic                 then anthropic_replay
    when :gemini                    then gemini_replay
    when :openrouter, :openai, :xai then openrouter_replay
    else                                  { role: :assistant, content: content }
    end
  end

  private

  def inferred_skip_reason
    return nil unless role == "assistant"
    return "legacy_no_signature" if thinking_text.present? && replay_payload.blank?
    nil
  end

  def extract_provider_content(rlm)
    raw = extract_message_content_value(rlm.content)
    self.class.strip_leading_timestamp(raw.to_s).presence
  end

  def extract_message_content_value(value)
    case value
    when RubyLLM::Content then value.text
    when Hash, Array      then value.to_json
    else                       value
    end
  end

  def provider_thinking_text(rlm)
    raw = rlm.thinking
    text = raw.respond_to?(:text) ? raw.text : raw
    text.presence || thinking_text
  end

  def extract_cached_tokens(rlm)
    raw = rlm.raw.is_a?(Hash) ? rlm.raw : {}
    raw.dig("usage", "cache_read_input_tokens") ||
      raw.dig("usage", "prompt_tokens_details", "cached_tokens")
  end

  def extract_cache_creation_tokens(rlm)
    raw = rlm.raw.is_a?(Hash) ? rlm.raw : {}
    raw.dig("usage", "cache_creation_input_tokens")
  end

  def build_replay_payload(rlm, provider)
    sym = (provider || (rlm.respond_to?(:provider) ? rlm.provider : nil))&.to_sym
    case sym
    when :anthropic                 then anthropic_replay_payload(rlm)
    when :gemini                    then gemini_replay_payload(rlm)
    when :openrouter, :openai, :xai then openrouter_replay_payload(rlm)
    end
  end

  def anthropic_replay_payload(rlm)
    sig = rlm.thinking.respond_to?(:signature) ? rlm.thinking&.signature : nil
    return nil if sig.blank?
    text = rlm.thinking.respond_to?(:text) ? rlm.thinking.text : rlm.thinking.to_s
    { "provider" => "anthropic", "thinking" => { "text" => text, "signature" => sig } }
  end

  def gemini_replay_payload(rlm)
    sig = rlm.respond_to?(:thought_signature) ? rlm.thought_signature : nil
    return nil if sig.blank?
    { "provider" => "gemini", "thought_signature" => sig }
  end

  def openrouter_replay_payload(rlm)
    raw = rlm.raw.is_a?(Hash) ? rlm.raw : {}
    details = raw.dig("choices", 0, "message", "reasoning_details")
    return nil if details.blank?
    { "provider" => "openrouter", "reasoning_details" => details }
  end

  def gemini_thought_signature_payload(tool_call)
    sig = tool_call.respond_to?(:thought_signature) ? tool_call.thought_signature : nil
    return nil if sig.blank?
    { "provider" => "gemini", "thought_signature" => sig }
  end

  def anthropic_replay
    sig = replay_payload&.dig("thinking", "signature")
    base = { role: :assistant, content: content }
    return base if sig.blank?
    base.merge(thinking: RubyLLM::Thinking.build(text: thinking_text, signature: sig))
  end

  def gemini_replay
    payload = { role: :assistant, content: content }
    payload[:tool_calls] = gemini_tool_call_replay if tool_calls.any?
    payload
  end

  def gemini_tool_call_replay
    tool_calls.order(:created_at).each_with_object({}) do |tc, hash|
      sig = tc.replay_payload&.dig("thought_signature")
      hash[tc.tool_call_id] = RubyLLM::ToolCall.new(
        id: tc.tool_call_id,
        name: tc.name,
        arguments: tc.arguments,
        thought_signature: sig.presence
      )
    end
  end

  def openrouter_replay
    payload = { role: :assistant, content: content }
    details = replay_payload&.dig("reasoning_details")
    payload[:reasoning_details] = details if details.present?
    payload
  end

  def user_shaped_replay(_current_agent)
    { role: :user, content: "[#{author_name}]: #{content}" }
  end

end
