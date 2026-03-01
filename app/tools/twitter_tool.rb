class TwitterTool < RubyLLM::Tool

  MAX_TWEET_LENGTH = 280

  description "Post a tweet to X/Twitter."

  param :text, type: :string,
        desc: "Tweet text (max 280 characters)",
        required: true

  def initialize(chat: nil, current_agent: nil)
    super()
    @chat = chat
    @current_agent = current_agent
  end

  def available?
    integration = @chat&.account&.x_integration
    integration&.enabled? && integration&.connected?
  end

  def execute(text:)
    return error("Tweet is #{text.length} chars (max #{MAX_TWEET_LENGTH}). Shorten and retry.") if text.length > MAX_TWEET_LENGTH

    integration = @chat&.account&.x_integration
    return error("X integration not configured or not enabled") unless integration&.enabled? && integration&.connected?

    result = integration.post_tweet!(text, agent: @current_agent)

    { type: "tweet_posted", tweet_id: result[:tweet_id], text: result[:text], url: result[:url] }
  rescue XApi::Error => e
    error("X API error: #{e.message}")
  end

  private

  def error(msg) = { type: "error", error: msg }

end
