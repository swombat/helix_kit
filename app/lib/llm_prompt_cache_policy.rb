class LlmPromptCachePolicy

  def self.system_messages(stable:, dynamic:, provider:)
    return automatic_cache_messages(stable, dynamic) unless provider.to_sym == :anthropic

    anthropic_cache_messages(stable, dynamic)
  end

  def self.transcript_messages(messages:, provider:)
    return messages unless provider.to_sym == :anthropic

    annotate_anthropic_transcript(messages)
  end

  def self.anthropic_cache_messages(stable, dynamic)
    messages = [
      {
        role: "system",
        content: anthropic_content(stable)
      }
    ]
    messages << { role: "system", content: dynamic } if dynamic.present?
    messages
  end

  def self.annotate_anthropic_transcript(messages)
    cacheable_index = messages.rindex { |message| message[:content].is_a?(String) }
    return messages if cacheable_index.nil?

    messages.map.with_index do |message, index|
      next message unless index == cacheable_index

      message.merge(content: anthropic_content(message[:content]))
    end
  end

  def self.anthropic_content(text)
    RubyLLM::Providers::Anthropic::Content.new(
      text,
      cache_control: {
        type: "ephemeral",
        ttl: ENV.fetch("HELIX_ANTHROPIC_CACHE_TTL", "1h")
      }
    )
  end

  def self.automatic_cache_messages(stable, dynamic)
    content = [ stable, dynamic.presence ].compact.join("\n\n")
    [ { role: "system", content: content } ]
  end

  private_class_method :anthropic_cache_messages, :annotate_anthropic_transcript,
    :anthropic_content, :automatic_cache_messages

end
