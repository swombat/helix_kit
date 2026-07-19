class LlmPromptCachePolicy

  def self.system_messages(stable:, dynamic:, provider:)
    return automatic_cache_messages(stable, dynamic) unless provider.to_sym == :anthropic

    anthropic_cache_messages(stable, dynamic)
  end

  def self.anthropic_cache_messages(stable, dynamic)
    messages = [
      {
        role: "system",
        content: RubyLLM::Providers::Anthropic::Content.new(stable, cache: true)
      }
    ]
    messages << { role: "system", content: dynamic } if dynamic.present?
    messages
  end

  def self.automatic_cache_messages(stable, dynamic)
    content = [ stable, dynamic.presence ].compact.join("\n\n")
    [ { role: "system", content: content } ]
  end

  private_class_method :anthropic_cache_messages, :automatic_cache_messages

end
