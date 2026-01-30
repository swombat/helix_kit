class Agent < ApplicationRecord

  include ActionView::Helpers::DateHelper
  include Broadcastable
  include ObfuscatesId
  include JsonAttributes
  include SyncAuthorizable
  include TelegramNotifiable

  # Initiation limits
  INITIATION_CAP = 2
  RECENTLY_INITIATED_WINDOW = 48.hours

  belongs_to :account
  has_many :chat_agents, dependent: :destroy
  has_many :chats, through: :chat_agents
  has_many :memories, class_name: "AgentMemory", dependent: :destroy

  before_validation :clean_enabled_tools

  VALID_COLOURS = %w[
    slate gray zinc neutral stone
    red orange amber yellow lime green
    emerald teal cyan sky blue indigo
    violet purple fuchsia pink rose
  ].freeze

  VALID_ICONS = %w[
    Robot Brain Sparkle Lightning Star Heart Sun Moon Eye Globe
    Compass Rocket Atom Lightbulb Crown Shield Fire Target Trophy
    Flask Code Cube PuzzlePiece Cat Dog Bird Alien Ghost Detective
    Butterfly Flower Tree Leaf
  ].freeze

  validates :name, presence: true,
                   length: { maximum: 100 },
                   uniqueness: { scope: :account_id }
  validates :system_prompt, length: { maximum: 50_000 }
  validates :reflection_prompt, length: { maximum: 10_000 }
  validates :memory_reflection_prompt, length: { maximum: 10_000 }
  validates :colour, inclusion: { in: VALID_COLOURS }, allow_nil: true
  validates :icon, inclusion: { in: VALID_ICONS }, allow_nil: true
  validates :thinking_budget,
            numericality: { greater_than_or_equal_to: 1000, less_than_or_equal_to: 50000 },
            allow_nil: true
  validate :enabled_tools_must_be_valid

  broadcasts_to :account

  scope :active, -> { where(active: true) }
  scope :by_name, -> { order(:name) }

  json_attributes :name, :system_prompt, :reflection_prompt, :memory_reflection_prompt,
                  :model_id, :model_label, :enabled_tools, :active?, :colour, :icon,
                  :memories_count, :thinking_enabled, :thinking_budget,
                  :telegram_bot_username, :telegram_configured?

  def self.available_tools
    Dir[Rails.root.join("app/tools/*_tool.rb")].filter_map do |file|
      File.basename(file, ".rb").camelize.constantize
    rescue NameError => e
      Rails.logger.warn("Agent.available_tools: Failed to load #{file} - #{e.message}")
      nil
    end
  end

  def tools
    return [] if enabled_tools.blank?

    enabled_tools.filter_map do |name|
      name.constantize
    rescue NameError => e
      Rails.logger.warn("Agent##{id}: Tool #{name} not found - #{e.message}")
      nil
    end
  end

  def model_label
    Chat::MODELS.find { |m| m[:model_id] == model_id }&.dig(:label) || model_id
  end

  def uses_thinking?
    thinking_enabled? && Chat.supports_thinking?(model_id)
  end

  def memory_context
    active = memories.for_prompt.to_a
    return nil if active.empty?

    [
      core_memory_section(active),
      journal_memory_section(active)
    ].compact.join("\n\n").then { |s| "# Your Private Memory\n\n#{s}" }
  end

  def memories_count
    raw = memories.group(:memory_type).count
    { core: raw.fetch("core", 0), journal: raw.fetch("journal", 0) }
  end

  # Conversation initiation methods

  def at_initiation_cap?
    pending_initiated_conversations.count >= INITIATION_CAP
  end

  def pending_initiated_conversations
    chats.kept.awaiting_human_response.where(initiated_by_agent: self)
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

  def build_initiation_prompt(conversations:, recent_initiations:, human_activity:)
    <<~PROMPT
      #{system_prompt}

      #{memory_context}

      # Self-Initiated Decision
      No human has prompted you. You are independently deciding whether to start or continue a conversation.
      This is entirely your choice — consider whether you have something meaningful to say.
      You may choose nothing with no penalty; default to nothing if unsure.

      # Current Time
      #{Time.current.strftime('%Y-%m-%d %H:%M %Z')}

      # Team Members
      #{format_team_members}

      # Conversations You Could Continue
      #{format_conversations(conversations)}

      # Recent Agent Initiations (last 48 hours)
      #{format_recent_initiations(recent_initiations)}

      # Human Activity
      #{format_human_activity(human_activity)}

      # Your Status
      #{initiation_status}

      # Guidelines
      - Avoid initiating too many conversations at once (both you and other agents)
      - Consider human activity before initiating
      - Only continue conversations if you have something meaningful to add
      - Inactive conversations (48+ hours) may be worth reviving only for important topics

      # Your Task
      Decide whether to:
      1. Continue an existing conversation (provide conversation_id)
      2. Start a new conversation (provide topic and opening message)
      3. Do nothing this cycle (provide reason)

      Respond with JSON only:
      {"action": "continue", "conversation_id": "abc123", "reason": "..."}
      {"action": "initiate", "topic": "...", "message": "...", "reason": "..."}
      {"action": "nothing", "reason": "..."}
    PROMPT
  end

  private

  def clean_enabled_tools
    self.enabled_tools = enabled_tools.reject(&:blank?) if enabled_tools.present?
  end

  def enabled_tools_must_be_valid
    return if enabled_tools.blank?
    available = self.class.available_tools.map(&:name)
    invalid = enabled_tools - available
    errors.add(:enabled_tools, "contains invalid tools: #{invalid.join(', ')}") if invalid.any?
  end

  def core_memory_section(memories)
    core = memories.select(&:core?)
    return unless core.any?

    "## Core Memories (permanent)\n" + core.map { |m| "- #{m.content}" }.join("\n")
  end

  def journal_memory_section(memories)
    journal = memories.select(&:journal?)
    return unless journal.any?

    "## Recent Journal Entries\n" + journal.map { |m| "- [#{m.created_at.strftime('%Y-%m-%d')}] #{m.content}" }.join("\n")
  end

  # Conversation initiation helpers

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

  def initiation_status
    pending = pending_initiated_conversations.count
    last = last_initiation_at

    parts = []
    parts << "You have #{pending} initiated conversation(s) awaiting human response." if pending > 0
    parts << "Your last initiation: #{last ? "#{time_ago_in_words(last)} ago" : 'Never'}"
    parts << "Hard cap: #{INITIATION_CAP} pending initiations (you're at the limit)" if pending >= INITIATION_CAP
    parts.join("\n")
  end

end
