class Chat < ApplicationRecord

  include Discard::Model
  include Broadcastable
  include ObfuscatesId
  include SyncAuthorizable
  include JsonAttributes

  AGENT_ONLY_PREFIX = "[AGENT-ONLY]"

  acts_as_chat model: :ai_model, model_class: "AiModel", model_foreign_key: :ai_model_id

  belongs_to :account
  belongs_to :active_whiteboard, class_name: "Whiteboard", optional: true
  belongs_to :initiated_by_agent, class_name: "Agent", optional: true

  has_many :chat_agents, dependent: :destroy
  has_many :agents, through: :chat_agents

  validates :agents, length: { minimum: 1, message: "must include at least one agent" }, if: :manual_responses?

  json_attributes :title_or_default, :model_id, :model_label, :ai_model_name, :updated_at_formatted,
                  :updated_at_short, :message_count, :total_tokens, :web_access, :manual_responses,
                  :participants_json, :archived_at, :discarded_at, :archived, :discarded, :respondable, :agent_only, :summary do |hash, options|
    # For sidebar format, only include attributes used by the chat list UI.
    if options&.dig(:as) == :sidebar_json
      hash.slice!(
        "id",
        "title",
        "title_or_default",
        "updated_at",
        "updated_at_short",
        "message_count",
        "manual_responses",
        "participants_json",
        "archived",
        "discarded",
        "agent_only"
      )
    end
    hash
  end

  def self.json_attrs_for(options = nil)
    return json_attrs unless options&.dig(:as) == :sidebar_json

    json_attrs - [
      :model_id,
      :model_label,
      :ai_model_name,
      :updated_at_formatted,
      :total_tokens,
      :web_access,
      :archived_at,
      :discarded_at,
      :respondable,
      :summary
    ]
  end

  broadcasts_to :account

  # Custom validation since model_id is resolved in before_save
  validate :model_must_be_present

  # Set defaults for model storage (OpenRouter format in DB, direct routing in to_llm)
  after_initialize :configure_defaults

  after_create_commit -> { GenerateTitleJob.perform_later(self) }, unless: :title?

  # Scopes for archive and discard functionality
  scope :kept, -> { undiscarded }
  scope :archived, -> { where.not(archived_at: nil) }
  scope :active, -> { where(archived_at: nil) }

  # Scopes for agent-only threads (title starts with [AGENT-ONLY])
  scope :agent_only, -> { where("title LIKE ?", "#{AGENT_ONLY_PREFIX}%") }
  scope :not_agent_only, -> { where("title NOT LIKE ? OR title IS NULL", "#{AGENT_ONLY_PREFIX}%") }

  # Scopes for agent-initiated conversations
  scope :initiated, -> { where.not(initiated_by_agent_id: nil) }
  scope :awaiting_human_response, -> {
    initiated.where.not(
      id: Message.where(role: "user").where.not(user_id: nil).select(:chat_id)
    )
  }

  # Available AI models grouped by category
  # Model IDs from OpenRouter API: https://openrouter.ai/api/v1/models
  # provider_model_id: the model ID used when calling the provider's direct API
  MODELS = [
    # Top Models - Flagship from each major provider
    {
      model_id: "openai/gpt-5.2",
      label: "GPT-5.2",
      group: "Top Models",
      provider_model_id: "gpt-5.2",
      thinking: { supported: true }
    },
    {
      model_id: "anthropic/claude-opus-4.6",
      label: "Claude Opus 4.6",
      group: "Top Models",
      provider_model_id: "claude-opus-4-6",
      thinking: { supported: true, requires_direct_api: true }
    },
    {
      model_id: "google/gemini-3-pro-preview",
      label: "Gemini 3 Pro",
      group: "Top Models",
      provider_model_id: "gemini-3-pro-preview",
      thinking: { supported: true },
      audio_input: true
    },
    {
      model_id: "x-ai/grok-4.1-fast",
      label: "Grok 4.1 Fast",
      group: "Top Models",
      provider_model_id: "grok-4.1-fast",
      thinking: { supported: true }
    },
    { model_id: "deepseek/deepseek-v3.2", label: "DeepSeek V3.2", group: "Top Models" },

    # OpenAI
    {
      model_id: "openai/gpt-5.1",
      label: "GPT-5.1",
      group: "OpenAI",
      provider_model_id: "gpt-5.1",
      thinking: { supported: true }
    },
    {
      model_id: "openai/gpt-5",
      label: "GPT-5",
      group: "OpenAI",
      provider_model_id: "gpt-5",
      thinking: { supported: true }
    },
    {
      model_id: "openai/gpt-5-mini",
      label: "GPT-5 Mini",
      group: "OpenAI",
      provider_model_id: "gpt-5-mini"
    },
    {
      model_id: "openai/gpt-5-nano",
      label: "GPT-5 Nano",
      group: "OpenAI",
      provider_model_id: "gpt-5-nano"
    },
    {
      model_id: "openai/o3",
      label: "O3",
      group: "OpenAI",
      provider_model_id: "o3"
    },
    {
      model_id: "openai/o3-mini",
      label: "O3 Mini",
      group: "OpenAI",
      provider_model_id: "o3-mini"
    },
    { model_id: "openai/o4-mini-high", label: "O4 Mini High", group: "OpenAI" },
    {
      model_id: "openai/o4-mini",
      label: "O4 Mini",
      group: "OpenAI",
      provider_model_id: "o4-mini"
    },
    {
      model_id: "openai/o1",
      label: "O1",
      group: "OpenAI",
      provider_model_id: "o1"
    },
    {
      model_id: "openai/gpt-4.1",
      label: "GPT-4.1",
      group: "OpenAI",
      provider_model_id: "gpt-4.1"
    },
    {
      model_id: "openai/gpt-4.1-mini",
      label: "GPT-4.1 Mini",
      group: "OpenAI",
      provider_model_id: "gpt-4.1-mini"
    },
    {
      model_id: "openai/gpt-4o",
      label: "GPT-4o",
      group: "OpenAI",
      provider_model_id: "gpt-4o"
    },
    {
      model_id: "openai/gpt-4o-mini",
      label: "GPT-4o Mini",
      group: "OpenAI",
      provider_model_id: "gpt-4o-mini"
    },

    # Anthropic
    {
      model_id: "anthropic/claude-opus-4.5",
      label: "Claude Opus 4.5",
      group: "Anthropic",
      provider_model_id: "claude-opus-4-5-20251101",
      thinking: { supported: true, requires_direct_api: true }
    },
    {
      model_id: "anthropic/claude-sonnet-4.5",
      label: "Claude Sonnet 4.5",
      group: "Anthropic",
      provider_model_id: "claude-sonnet-4-5-20250929",
      thinking: { supported: true, requires_direct_api: true }
    },
    {
      model_id: "anthropic/claude-haiku-4.5",
      label: "Claude Haiku 4.5",
      group: "Anthropic",
      provider_model_id: "claude-haiku-4-5-20251001"
    },
    {
      model_id: "anthropic/claude-opus-4.1",
      label: "Claude Opus 4.1",
      group: "Anthropic",
      provider_model_id: "claude-opus-4-1-20250805",
      thinking: { supported: true, requires_direct_api: true }
    },
    {
      model_id: "anthropic/claude-opus-4",
      label: "Claude Opus 4",
      group: "Anthropic",
      provider_model_id: "claude-opus-4-20250514",
      thinking: { supported: true, requires_direct_api: true }
    },
    {
      model_id: "anthropic/claude-sonnet-4",
      label: "Claude Sonnet 4",
      group: "Anthropic",
      provider_model_id: "claude-sonnet-4-20250514",
      thinking: { supported: true, requires_direct_api: true }
    },
    {
      model_id: "anthropic/claude-3.7-sonnet",
      label: "Claude 3.7 Sonnet",
      group: "Anthropic",
      provider_model_id: "claude-3-7-sonnet-latest",
      thinking: { supported: true }
    },
    {
      model_id: "anthropic/claude-3.5-sonnet",
      label: "Claude 3.5 Sonnet",
      group: "Anthropic",
      provider_model_id: "claude-3-5-sonnet-latest"
    },
    {
      model_id: "anthropic/claude-3-opus",
      label: "Claude 3 Opus",
      group: "Anthropic",
      provider_model_id: "claude-3-opus-latest"
    },

    # Google
    {
      model_id: "google/gemini-3-flash-preview",
      label: "Gemini 3 Flash",
      group: "Google",
      provider_model_id: "gemini-3-flash-preview",
      audio_input: true
    },
    {
      model_id: "google/gemini-2.5-pro",
      label: "Gemini 2.5 Pro",
      group: "Google",
      provider_model_id: "gemini-2.5-pro",
      audio_input: true
    },
    {
      model_id: "google/gemini-2.5-flash",
      label: "Gemini 2.5 Flash",
      group: "Google",
      provider_model_id: "gemini-2.5-flash",
      audio_input: true
    },

    # xAI - Grok models with reasoning support
    # grok-3-mini: Shows thinking traces, uses reasoning_effort parameter
    # grok-4-fast/4.1-fast: Can toggle reasoning on/off
    # grok-4/grok-3: Built-in reasoning but not exposed/configurable
    {
      model_id: "x-ai/grok-3-mini",
      label: "Grok 3 Mini",
      group: "xAI",
      provider_model_id: "grok-3-mini",
      thinking: { supported: true }
    },
    {
      model_id: "x-ai/grok-4-fast",
      label: "Grok 4 Fast",
      group: "xAI",
      provider_model_id: "grok-4-fast",
      thinking: { supported: true }
    },
    {
      model_id: "x-ai/grok-4",
      label: "Grok 4",
      group: "xAI",
      provider_model_id: "grok-4"
    },
    {
      model_id: "x-ai/grok-3",
      label: "Grok 3",
      group: "xAI",
      provider_model_id: "grok-3"
    },

    # DeepSeek
    { model_id: "deepseek/deepseek-r1", label: "DeepSeek R1", group: "DeepSeek" },
    { model_id: "deepseek/deepseek-v3", label: "DeepSeek V3", group: "DeepSeek" }
  ].freeze

  # Summary generation constants
  SUMMARY_COOLDOWN = 1.hour
  SUMMARY_MAX_WORDS = 200

  def self.model_config(model_id)
    MODELS.find { |m| m[:model_id] == model_id }
  end

  def self.supports_thinking?(model_id)
    model_config(model_id)&.dig(:thinking, :supported) == true
  end

  def self.supports_audio_input?(model_id)
    model_config(model_id)&.dig(:audio_input) == true
  end

  def self.requires_direct_api_for_thinking?(model_id)
    model_config(model_id)&.dig(:thinking, :requires_direct_api) == true
  end

  def self.provider_model_id(model_id)
    config = model_config(model_id)
    config&.dig(:provider_model_id) || config&.dig(:thinking, :provider_model_id) || model_id.to_s.sub(%r{^.+/}, "")
  end

  def self.resolve_provider(model_id)
    ResolvesProvider.resolve_provider(model_id)
  end

  scope :latest, -> { order(updated_at: :desc) }

  # Create chat with optional initial message
  def self.create_with_message!(attributes, message_content: nil, user: nil, files: nil, agent_ids: nil)
    transaction do
      chat = new(attributes)
      chat.agent_ids = agent_ids if agent_ids.present?
      chat.save!

      if message_content.present? || (files.present? && files.any?)
        message = chat.messages.create!({
          content: message_content || "",
          role: "user",
          user: user,
          skip_content_validation: message_content.blank? && files.present? && files.any? # Skip content validation if we have files but no content
        })
        message.attachments.attach(files) if files.present? && files.any?

        AiResponseJob.perform_later(chat) unless chat.manual_responses?
      end
      chat
    end
  end

  # Create a chat initiated by an agent with their opening message
  def self.initiate_by_agent!(agent, topic:, message:, reason: nil, invite_agent_ids: [])
    invited_agents = resolve_invited_agents(agent.account, invite_agent_ids)

    transaction do
      chat = agent.account.chats.new(
        title: topic,
        manual_responses: true,
        model_id: agent.model_id,
        initiated_by_agent: agent,
        initiation_reason: reason
      )
      chat.agent_ids = [ agent.id ] + invited_agents.map(&:id)
      chat.save!
      chat.messages.create!(role: "assistant", agent: agent, content: message)
      chat
    end.tap do |chat|
      agent.notify_subscribers!(chat.messages.last, chat)
      invited_agents.each_with_index do |invited_agent, i|
        delay = (i + 1).minutes
        ManualAgentResponseJob.set(wait: delay).perform_later(chat, invited_agent)
      end
    end
  end

  def self.resolve_invited_agents(account, obfuscated_ids)
    return [] if obfuscated_ids.blank?
    real_ids = obfuscated_ids.filter_map { |oid| Agent.decode_id(oid) }
    account.agents.active.where(id: real_ids).to_a
  end

  def title_or_default
    title.presence || "New Conversation"
  end

  def agent_only?
    title&.start_with?(AGENT_ONLY_PREFIX)
  end

  # Alias for json_attributes
  def agent_only
    agent_only?
  end

  # Returns cached JSON representation, invalidated when chat is updated
  # (which happens automatically when messages are added via touch: true)
  def cached_json(as: nil)
    Rails.cache.fetch(json_cache_key(as: as)) do
      as.present? ? as_json(as: as) : as_json
    end
  end

  def cached_sidebar_json
    cached_json(as: :sidebar_json)
  end

  def self.cached_json_for(chats, as: nil)
    return [] if chats.blank?

    entries = chats.map { |chat| [ chat, chat.json_cache_key(as: as) ] }
    cached = Rails.cache.read_multi(*entries.map(&:last))
    missing = {}

    entries.each do |chat, key|
      next if cached.key?(key)

      missing[key] = as.present? ? chat.as_json(as: as) : chat.as_json
    end

    if missing.any?
      if Rails.cache.respond_to?(:write_multi)
        Rails.cache.write_multi(missing)
      else
        missing.each { |key, value| Rails.cache.write(key, value) }
      end
    end

    entries.map { |_, key| cached[key] || missing[key] }
  end

  def json_cache_key(as: nil)
    return cache_key_with_version unless as.present?

    "#{cache_key_with_version}/json/#{as}"
  end

  # Override RubyLLM's model_id getter to return the string value
  # (RubyLLM's version returns ai_model&.model_id which is nil before save)
  def model_id
    model_id_string_value
  end

  def model_label
    model = MODELS.find { |m| m[:model_id] == model_id_string_value }
    model ? model[:label] : model_id_string_value
  end

  # Returns the friendly model name, or nil if not found in MODELS list
  def ai_model_name
    model = MODELS.find { |m| m[:model_id] == model_id_string_value }
    model&.dig(:label)
  end

  # Get the model_id string from either the pending value, association, or legacy column
  def model_id_string_value
    @model_string || ai_model&.model_id || model_id_string
  end

  def updated_at_formatted
    updated_at.strftime("%b %d at %l:%M %p")
  end

  def updated_at_short
    updated_at.strftime("%b %d")
  end

  def message_count
    messages.count
  end

  # Returns paginated messages for display
  # Uses cursor-based pagination with before_id for efficient loading of older messages
  # Returns the most recent N messages that are older than before_id, in ascending order for display
  def messages_page(before_id: nil, limit: 30)
    scope = messages.includes(:user, :agent).with_attached_attachments.with_attached_audio_recording
    scope = scope.where("messages.id < ?", Message.decode_id(before_id)) if before_id.present?
    # Use reorder to replace any existing ordering (from acts_as_chat),
    # get the most recent messages by ordering by ID DESC, limit, then reverse for display
    scope.reorder(id: :desc).limit(limit).reverse
  end

  # Returns total token count for all messages in this chat
  # Uses COALESCE to handle nil values in the database
  def total_tokens
    messages.sum("COALESCE(input_tokens, 0) + COALESCE(output_tokens, 0)")
  end

  # Archive/unarchive methods
  def archive!
    update!(archived_at: Time.current)
  end

  def unarchive!
    update!(archived_at: nil)
  end

  def archived?
    archived_at.present?
  end

  # Alias for json_attributes
  def archived
    archived?
  end

  # Alias for json_attributes (provided by Discard)
  def discarded
    discarded?
  end

  # Returns false if the chat is archived or discarded, meaning it cannot receive new messages
  def respondable?
    !archived? && !discarded?
  end

  # Alias for json_attributes
  def respondable
    respondable?
  end

  # Returns participants info for group chats (agents + unique humans)
  def participants_json
    return [] unless manual_responses?

    participants = []

    # Add agents with their icons and colours
    agents.each do |agent|
      participants << {
        type: "agent",
        name: agent.name,
        icon: agent.icon,
        colour: agent.colour
      }
    end

    # Add unique human participants from messages
    messages.unscope(:order).where.not(user_id: nil).distinct.pluck(:user_id).each do |user_id|
      user = User.find(user_id)
      participants << {
        type: "human",
        name: user.full_name.presence || user.email_address.split("@").first,
        avatar_url: user.avatar_url,
        colour: user.chat_colour
      }
    end

    participants
  end

  # Override RubyLLM's to_llm to route through direct provider APIs when available.
  # The AiModel record stays in OpenRouter format (for DB storage), but actual API
  # calls go to the direct provider for lower latency and cost.
  def to_llm
    original_model_id = model_id_string_value
    provider_config = self.class.resolve_provider(original_model_id)

    @chat = (context || RubyLLM).chat(
      model: provider_config[:model_id],
      provider: provider_config[:provider]
    )

    messages_association.each do |msg|
      @chat.add_message(msg.to_llm)
    end

    setup_persistence_callbacks
  end

  # Configure tools for RubyLLM based on settings
  def available_tools
    return [] unless web_access?
    [ WebTool ]
  end

  # Group chat functionality
  def group_chat?
    manual_responses?
  end

  def trigger_agent_response!(agent)
    raise ArgumentError, "Agent not in this conversation" unless agents.include?(agent)
    raise ArgumentError, "This chat does not support manual responses" unless manual_responses?
    raise ArgumentError, "This conversation is archived or deleted" unless respondable?

    ManualAgentResponseJob.perform_later(self, agent)
  end

  def trigger_all_agents_response!
    raise ArgumentError, "This chat does not support manual responses" unless manual_responses?
    raise ArgumentError, "No agents in this conversation" if agents.empty?
    raise ArgumentError, "This conversation is archived or deleted" unless respondable?

    # Get agent IDs in a consistent order
    agent_ids = agents.order(:id).pluck(:id)

    # Queue the job that will process all agents in sequence
    AllAgentsResponseJob.perform_later(self, agent_ids)
  end

  def trigger_mentioned_agents!(content)
    return if content.blank? || !manual_responses?

    mentioned_ids = agents.select { |agent|
      content.match?(/@#{Regexp.escape(agent.name)}\b/i)
    }.sort_by { |agent| content.index(/@#{Regexp.escape(agent.name)}\b/i) }.map(&:id)

    AllAgentsResponseJob.perform_later(self, mentioned_ids) if mentioned_ids.any?
  end

  def fork_with_title!(new_title)
    transaction do
      forked = account.chats.new(
        title: new_title,
        model_id: model_id,
        web_access: web_access,
        manual_responses: manual_responses
      )

      # Copy agents for group chats (must be set before save for validation)
      forked.agent_ids = agent_ids if manual_responses?
      forked.save!

      # Copy all messages with attachments
      messages.includes(:user, :agent, attachments_attachments: :blob).order(:created_at).each do |msg|
        new_msg = forked.messages.create!(
          content: msg.content,
          role: msg.role,
          user_id: msg.user_id,
          agent_id: msg.agent_id,
          input_tokens: msg.input_tokens,
          output_tokens: msg.output_tokens,
          tools_used: msg.tools_used,
          skip_content_validation: msg.content.blank?
        )

        # Duplicate attachments
        msg.attachments.each do |attachment|
          new_msg.attachments.attach(
            io: StringIO.new(attachment.download),
            filename: attachment.filename.to_s,
            content_type: attachment.content_type
          )
        end

        # Reuse audio recording blob (no re-upload needed)
        if msg.audio_recording.attached?
          new_msg.audio_recording.attach(msg.audio_recording.blob)
          new_msg.update_column(:audio_source, true)
        end
      end

      forked
    end
  end

  def audio_tools_available_for?(model_id)
    self.class.supports_audio_input?(model_id) && messages.where(audio_source: true).exists?
  end

  def build_context_for_agent(agent, thinking_enabled: false, initiation_reason: nil)
    [ system_message_for(agent, initiation_reason: initiation_reason) ] +
      messages_context_for(agent, thinking_enabled: thinking_enabled, audio_tools_enabled: audio_tools_available_for?(agent.model_id))
  end

  # Checks if extended thinking can be used for this agent in this conversation.
  # Returns false if any of the agent's historical assistant messages lack
  # thinking content AND signature (Anthropic requires valid signed thinking blocks).
  def thinking_compatible_for?(agent)
    agent_messages = messages.where(role: "assistant", agent_id: agent.id)
    agent_messages.all? do |msg|
      # Message is compatible if it has both thinking content and signature
      msg.thinking.present? && msg.thinking_signature.present?
    end
  end

  # Summary generation for API
  def summary_stale?
    summary_generated_at.nil? || summary_generated_at < SUMMARY_COOLDOWN.ago
  end

  def generate_summary!
    return summary unless summary_stale?
    return nil if messages.where(role: %w[user assistant]).count < 2

    new_summary = generate_summary_from_llm
    update!(summary: new_summary, summary_generated_at: Time.current) if new_summary.present?
    summary
  end

  # Returns transcript in a format suitable for the API
  def transcript_for_api
    messages.includes(:user, :agent)
            .where(role: %w[user assistant])
            .order(:created_at)
            .map { |m| format_message_for_api(m) }
  end

  # Queue moderation for all unmoderated messages with content
  def queue_moderation_for_all_messages
    unmoderated = messages.where(moderated_at: nil).where.not(content: [ nil, "" ])
    unmoderated.find_each { |message| ModerateMessageJob.perform_later(message) }
    unmoderated.count
  end

  private

  def configure_defaults
    # DB storage uses OpenRouter format (model IDs like "anthropic/claude-opus-4.6").
    # Actual API routing to direct providers happens in to_llm.
    self.provider = :openrouter
    self.assume_model_exists = true

    # Set default model if none specified (check all possible sources)
    unless @model_string.present? || ai_model_id.present? || model_id_string.present?
      self.model_id = "openrouter/auto"
    end
  end

  def model_must_be_present
    if @model_string.blank? && ai_model.blank? && model_id_string.blank?
      errors.add(:model_id, "can't be blank")
    end
  end

  # Group chat context building helpers
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

    lines = boards.map do |b|
      warning = b.over_recommended_length? ? " [OVER LIMIT - needs summarizing]" : ""
      "- #{b.name} (#{b.content.to_s.length} chars, rev #{b.revision})#{warning}: #{b.summary}"
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

    lines = summaries.map do |ca|
      "- [#{ca.chat.obfuscated_id}] \"#{ca.chat.title_or_default}\": #{ca.agent_summary}"
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
    messages_text = borrowed["messages"].map do |m|
      "[#{m['author']}]: #{m['content']}"
    end.join("\n")

    "# Borrowed Context from Conversation #{source_id}\n\n" \
    "You requested context from another conversation. Here are the recent messages:\n\n" \
    "#{messages_text}\n\n" \
    "This context is provided for reference only and will not appear in future activations."
  end

  def messages_context_for(agent, thinking_enabled: false, audio_tools_enabled: false)
    tz = user_timezone
    messages.includes(:user, :agent).order(:created_at)
      .reject { |msg| msg.content.blank? }  # Filter out empty messages (e.g., before tool calls)
      .reject { |msg| msg.used_tools? && msg.agent_id != agent.id }  # Exclude other agents' tool results
      .map { |msg| format_message_for_context(msg, agent, tz, thinking_enabled: thinking_enabled, audio_tools_enabled: audio_tools_enabled) }
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

  def format_message_for_context(message, current_agent, timezone, thinking_enabled: false, audio_tools_enabled: false)
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

    role = message.agent_id == current_agent.id ? "assistant" : "user"

    # Include file attachments if present using RubyLLM::Content
    # Exclude audio files when the model doesn't support audio input
    file_paths = message.file_paths_for_llm(include_audio: audio_tools_enabled)
    content = if file_paths.present?
      RubyLLM::Content.new(text_content, file_paths)
    else
      text_content
    end

    result = { role: role, content: content }

    # Include thinking for assistant messages when thinking mode is enabled.
    # Only include if both thinking content AND signature are present (Anthropic
    # requires valid cryptographic signatures on thinking blocks).
    if role == "assistant" && thinking_enabled && message.thinking.present?
      result[:thinking] = message.thinking
      result[:thinking_signature] = message.thinking_signature if message.thinking_signature.present?
    end

    result
  end

  # Summary generation helpers
  def generate_summary_from_llm
    transcript_lines = messages.where(role: %w[user assistant])
                               .order(:created_at)
                               .limit(20)
                               .map { |m| "#{m.role.titleize}: #{m.content.to_s.truncate(300)}" }

    return nil if transcript_lines.blank?

    prompt = Prompt.new(model: Prompt::LIGHT_MODEL, template: "generate_summary")
    prompt.render(messages: transcript_lines)
    prompt.execute_to_string&.squish&.truncate_words(SUMMARY_MAX_WORDS)
  rescue StandardError => e
    Rails.logger.error "Summary generation failed: #{e.message}"
    nil
  end

  def format_message_for_api(message)
    {
      role: message.role,
      content: message.content,
      author: api_author_name(message),
      timestamp: message.created_at.iso8601
    }
  end

  def api_author_name(message)
    if message.agent.present?
      message.agent.name
    elsif message.user.present?
      message.user.full_name.presence || message.user.email_address.split("@").first
    else
      message.role.titleize
    end
  end

end
