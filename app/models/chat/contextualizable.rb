module Chat::Contextualizable

  extend ActiveSupport::Concern

  def audio_tools_available_for?(model_id)
    self.class.supports_audio_input?(model_id) && messages.where(audio_source: true).exists?
  end

  def build_context_for_agent(agent, thinking_enabled: false, provider: nil, initiation_reason: nil)
    provider ||= self.class.resolve_provider(agent.model_id)[:provider]
    [ system_message_for(agent, initiation_reason: initiation_reason) ] +
      messages_context_for(agent,
        provider: provider,
        thinking_enabled: thinking_enabled,
        audio_tools_enabled: audio_tools_available_for?(agent.model_id),
        pdf_input_supported: self.class.supports_pdf_input?(agent.model_id))
  end

  private

  def system_message_for(agent, initiation_reason: nil)
    parts = []

    parts << (agent.system_prompt.presence || "You are #{agent.name}.")

    if (memory_context = agent.memory_context)
      parts << memory_context
    end

    account.users.each do |user|
      if (health_context = user.oura_health_context_labeled)
        parts << health_context
      end
    end

    if (whiteboard_index = whiteboard_index_context)
      parts << whiteboard_index
    end

    if (topic = conversation_topic_context)
      parts << topic
    end

    if (active_board = active_whiteboard_context)
      parts << active_board
    end

    if (cross_conv = format_cross_conversation_context(agent))
      parts << cross_conv
    end

    if (borrowed = format_borrowed_context(agent))
      parts << borrowed
    end

    if Rails.env.development?
      parts << "**DEVELOPMENT TESTING MODE**: You are currently being tested on a development server using a production database backup. Any memories or changes you make will NOT be saved to the production server. This is a safe testing environment."
    end

    if agent_only?
      parts << "**AGENT-ONLY THREAD**: This conversation is not visible to humans. You are communicating privately with other agents. No notifications are sent to human users for messages in this thread."
    end

    if initiation_reason.present?
      parts << "You have chosen to continue this conversation of your own initiative. The user did not prompt you to do so. It was your choice. Your reasoning was: #{initiation_reason}"
    end

    if agent.voiced?
      parts << <<~VOICE.strip
        You have a voice. When your messages are played aloud, the ElevenLabs v3 engine renders
        them with full expressiveness. You can use tonal tags inline to shape how you sound:
        [whispers], [excited], [sarcastically], [sighs], [laughs], [serious], [gentle], [playful].
        Use these sparingly and naturally -- they should feel like genuine expression, not performance.
      VOICE
    end

    parts << "Current time: #{Time.current.in_time_zone(user_timezone).strftime('%A, %Y-%m-%d %H:%M %Z')}"

    parts << "You are participating in a group conversation."
    parts << "Other participants: #{participant_description(agent)}."

    { role: "system", content: parts.join("\n\n") }
  end

  def whiteboard_index_context
    boards = account.whiteboards.active.by_name
    return if boards.empty?

    lines = boards.map do |board|
      warning = board.over_recommended_length? ? " [OVER LIMIT - needs summarizing]" : ""
      "- #{board.name} (#{board.content.to_s.length} chars, rev #{board.revision})#{warning}: #{board.summary}"
    end

    "# Shared Whiteboards\n\n" \
      "Available boards for collaborative notes:\n\n" \
      "#{lines.join("\n")}\n\n" \
      "Use the whiteboard tool to view, create, update, or set an active board."
  end

  def active_whiteboard_context
    return unless active_whiteboard && !active_whiteboard.deleted?

    "# Active Whiteboard: #{active_whiteboard.name}\n\n" \
      "#{active_whiteboard.content}"
  end

  def conversation_topic_context
    return unless title.present?

    "# Conversation Topic\n\n" \
      "This conversation is titled: \"#{title}\""
  end

  def format_cross_conversation_context(agent)
    summaries = agent.other_conversation_summaries(exclude_chat_id: id)
    return nil if summaries.empty?

    lines = summaries.map do |chat_agent|
      "- [#{chat_agent.chat.obfuscated_id}] \"#{chat_agent.chat.title_or_default}\": #{chat_agent.agent_summary}"
    end

    "# Your Other Active Conversations\n\n" \
      "You are also participating in these conversations (updated in last 6 hours):\n\n" \
      "#{lines.join("\n")}\n\n" \
      "If any of these are relevant to the current discussion, you can use the borrow_context " \
      "tool with the conversation ID to pull in recent messages for reference."
  end

  def format_borrowed_context(agent)
    chat_agent = chat_agents.find_by(agent_id: agent.id)
    borrowed = chat_agent&.borrowed_context_json
    return nil if borrowed.blank?

    source_id = borrowed["source_conversation_id"]
    messages_text = borrowed["messages"].map do |message|
      "[#{message['author']}]: #{message['content']}"
    end.join("\n")

    "# Borrowed Context from Conversation #{source_id}\n\n" \
      "You requested context from another conversation. Here are the recent messages:\n\n" \
      "#{messages_text}\n\n" \
      "This context is provided for reference only and will not appear in future activations."
  end

  def messages_context_for(agent, provider:, thinking_enabled: false, audio_tools_enabled: false, pdf_input_supported: true)
    timezone = user_timezone
    messages.includes(:user, :agent).order(:created_at)
      .reject { |message| message.content.blank? }
      .reject { |message| message.used_tools? && message.agent_id != agent.id }
      .map { |message| format_message_for_context(message, agent, timezone, provider: provider, thinking_enabled: thinking_enabled, audio_tools_enabled: audio_tools_enabled, pdf_input_supported: pdf_input_supported) }
  end

  def participant_description(current_agent)
    humans = messages.unscope(:order).where.not(user_id: nil).joins(:user)
                     .distinct.pluck("users.email_address")
                     .map { |email| email.split("@").first }
    other_agents = agents.where.not(id: current_agent.id).pluck(:name)

    parts = []
    parts << "Humans: #{humans.join(', ')}" if humans.any?
    parts << "AI Agents: #{other_agents.join(', ')}" if other_agents.any?
    parts.join(". ")
  end

  def user_timezone
    @user_timezone ||= ActiveSupport::TimeZone[recent_user_timezone || "UTC"]
  end

  def recent_user_timezone
    messages.joins(user: :profile)
            .where.not(user_id: nil)
            .order(created_at: :desc)
            .limit(1)
            .pick("profiles.timezone")
  end

  def format_message_for_context(message, current_agent, timezone, provider:, thinking_enabled: false, audio_tools_enabled: false, pdf_input_supported: true)
    timestamp = message.created_at.in_time_zone(timezone).strftime("[%Y-%m-%d %H:%M]")

    text_content = if message.agent_id == current_agent.id
      "#{timestamp} #{message.content}"
    elsif message.agent_id.present?
      "#{timestamp} [#{message.agent.name}]: #{message.content}"
    else
      name = message.user&.full_name.presence || message.user&.email_address&.split("@")&.first || "User"
      "#{timestamp} [#{name}]: #{message.content}"
    end

    if audio_tools_enabled && message.audio_source? && message.audio_recording.attached?
      text_content += " [voice message, audio_id: #{message.obfuscated_id}]"
    end

    unless pdf_input_supported
      pdf_text = message.pdf_text_for_llm
      text_content += "\n\n#{pdf_text}" if pdf_text.present?
    end

    role = message.agent_id == current_agent.id ? "assistant" : "user"

    file_paths = message.file_paths_for_llm(include_audio: audio_tools_enabled, include_pdf: pdf_input_supported)
    content = if file_paths.present?
      RubyLLM::Content.new(text_content, file_paths)
    else
      text_content
    end

    result = { role: role, content: content }

    return result unless role == "assistant" && thinking_enabled && message.role == "assistant"

    replay = message.replay_for(provider, current_agent: current_agent)
    [ :thinking, :reasoning_details, :tool_calls ].each do |key|
      result[key] = replay[key] if replay[key]
    end

    result
  end

end
