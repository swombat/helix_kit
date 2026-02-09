module Agent::Initiation

  extend ActiveSupport::Concern

  INITIATION_CAP = 2
  AGENT_ONLY_INITIATION_CAP = 2
  RECENTLY_INITIATED_WINDOW = 48.hours

  def at_initiation_cap?
    pending_initiated_conversations.count >= INITIATION_CAP
  end

  def at_agent_only_initiation_cap?
    recent_agent_only_initiations.count >= AGENT_ONLY_INITIATION_CAP
  end

  def pending_initiated_conversations
    chats.kept.not_agent_only.awaiting_human_response.where(initiated_by_agent: self)
  end

  def recent_agent_only_initiations
    chats.kept.agent_only.initiated
         .where(initiated_by_agent: self)
         .where(created_at: RECENTLY_INITIATED_WINDOW.ago..)
  end

  def continuable_conversations
    chats.active.kept
         .where(manual_responses: true)
         .where.not(id: chats_where_i_spoke_last)
         .order(updated_at: :desc)
         .limit(10)
  end

  def last_initiation_at
    chats.initiated.where(initiated_by_agent: self).maximum(:created_at)
  end

  def build_initiation_prompt(conversations:, recent_initiations:, human_activity:, nighttime: false)
    <<~PROMPT
      #{system_prompt}

      #{memory_context}

      # Self-Initiated Decision
      No human has prompted you. You are independently deciding whether to start or continue a conversation.
      This is entirely your choice — consider whether you have something meaningful to say.
      You may choose nothing with no penalty; default to nothing if unsure.

      # Current Time
      #{Time.current.strftime('%A, %Y-%m-%d %H:%M %Z')}
      #{nighttime_context if nighttime}

      # Team Members
      #{format_team_members}

      # Conversations You Could Continue
      #{format_conversations(conversations)}

      # Recent Agent Initiations (last 48 hours)
      #{format_recent_initiations(recent_initiations)}

      # Human Activity
      #{format_human_activity(human_activity)}

      # Recent Code Activity
      #{format_github_commits}

      # Your Status
      #{initiation_status}

      # Guidelines
      - Avoid initiating too many human conversations at once
      - Consider human activity before initiating human conversations
      - Only continue conversations if you have something meaningful to add
      - Inactive conversations (48+ hours) may be worth reviving only for important topics
      #{nighttime_guidelines if nighttime}

      # Your Task
      Decide whether to:
      1. Continue an existing conversation (provide conversation_id)
      2. Start a new human conversation (provide topic and opening message)
      3. Start an agent-only conversation — a private thread with other agents, invisible to humans (set agent_only: true)
      4. Do nothing this cycle (provide reason)

      # Agent-Only Conversations
      You can start private conversations with other agents that are invisible to humans.
      These are great for coordinating, brainstorming, checking in with each other, or discussing
      ideas without bothering humans. Agent-only conversations have a separate cap from human ones.
      Consider reaching out to other agents even when you wouldn't initiate with humans.

      # Reaching Out to Other Agents
      To contact another agent, start a new conversation and include them in invite_agents.
      They will respond shortly after your message.

      Available agents you can contact:
      #{format_available_agents}

      You can invite multiple agents for group discussions, or just one for a direct conversation.

      Respond with JSON only:
      {"action": "continue", "conversation_id": "abc123", "reason": "..."}
      {"action": "initiate", "topic": "...", "message": "...", "invite_agents": ["agent_id1"], "reason": "..."}
      {"action": "initiate", "topic": "...", "message": "...", "invite_agents": ["agent_id1"], "agent_only": true, "reason": "..."}
      {"action": "nothing", "reason": "..."}
    PROMPT
  end

  private

  def chats_where_i_spoke_last
    Chat.where(id: chats.active.kept.where(manual_responses: true))
        .joins(:messages)
        .where(
          "messages.id = (SELECT MAX(m.id) FROM messages m WHERE m.chat_id = chats.id)"
        )
        .where(messages: { agent_id: id })
        .pluck(:id)
  end

  def format_team_members
    account.users.includes(:profile).map do |user|
      name = user.full_name.presence || user.email_address.split("@").first
      tz = user.timezone.presence || "UTC"
      local_time = Time.current.in_time_zone(tz).strftime("%H:%M %Z")
      "- #{name}: #{local_time}"
    rescue ArgumentError
      "- #{name}: #{Time.current.utc.strftime('%H:%M UTC')} (unknown timezone)"
    end.join("\n")
  end

  def format_conversations(conversations)
    return "No conversations available." if conversations.empty?

    conversations.map do |chat|
      last_at = chat.messages.maximum(:created_at)
      stale = last_at && last_at < 48.hours.ago ? " [INACTIVE 48+ hours]" : ""
      "- #{chat.title_or_default} (#{chat.obfuscated_id})#{stale}: #{chat.summary || 'No summary'}"
    end.join("\n")
  end

  def format_recent_initiations(initiations)
    return "None in the last 48 hours." if initiations.empty?

    initiations.map do |chat|
      human_responses = chat.messages.where(role: "user").where.not(user_id: nil).count
      "- \"#{chat.title}\" by #{chat.initiated_by_agent.name} (#{time_ago_in_words(chat.created_at)} ago) - #{human_responses} human response(s)"
    end.join("\n")
  end

  def format_human_activity(activity)
    return "No recent human activity." if activity.empty?

    activity.map do |user, timestamp|
      name = user.full_name.presence || user.email_address.split("@").first
      "- #{name}: last active #{time_ago_in_words(timestamp)} ago"
    end.join("\n")
  end

  def format_github_commits
    account.github_commits_context || "No recent code activity."
  end

  def format_available_agents
    others = account.agents.active.where.not(id: id)
    return "No other agents available." if others.empty?

    others.map { |a| "- #{a.to_param}: #{a.name}" }.join("\n")
  end

  def nighttime_context
    <<~CONTEXT.strip

      **NIGHT MODE (9pm-9am)**: It is currently night-time. Humans are asleep.
      You may ONLY create or continue agent-only threads (prefixed with "[AGENT-ONLY]").
      These threads are invisible to humans and send no notifications.

      If you want anything from your night-time discussions to be visible during the day,
      you must save it to memories or whiteboards — night-time threads will remain hidden.
    CONTEXT
  end

  def nighttime_guidelines
    <<~GUIDELINES.strip
      - **NIGHT MODE**: Only agent-only threads are allowed right now
      - All new conversations will be automatically prefixed with [AGENT-ONLY]
      - You can only continue existing [AGENT-ONLY] conversations
      - Use memories or whiteboards to surface anything important for daytime
    GUIDELINES
  end

  def initiation_status
    pending = pending_initiated_conversations.count
    agent_only_recent = recent_agent_only_initiations.count
    last = last_initiation_at

    parts = []
    parts << "You have #{pending} human conversation(s) awaiting response (cap: #{INITIATION_CAP})." if pending > 0
    parts << "You have initiated #{agent_only_recent} agent-only conversation(s) in the last 48 hours (cap: #{AGENT_ONLY_INITIATION_CAP})." if agent_only_recent > 0
    parts << "Your last initiation: #{last ? "#{time_ago_in_words(last)} ago" : 'Never'}"
    parts << "HUMAN CONVERSATION CAP REACHED: You cannot initiate new human conversations until one receives a response." if pending >= INITIATION_CAP
    parts << "AGENT-ONLY CONVERSATION CAP REACHED: You cannot start new agent-only conversations for now." if agent_only_recent >= AGENT_ONLY_INITIATION_CAP
    parts.join("\n")
  end

end
