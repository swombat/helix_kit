class Chat < ApplicationRecord

  include Discard::Model
  include Broadcastable
  include ObfuscatesId
  include SyncAuthorizable
  include JsonAttributes

  acts_as_chat model: :ai_model, model_class: "AiModel", model_foreign_key: :ai_model_id

  belongs_to :account
  belongs_to :active_whiteboard, class_name: "Whiteboard", optional: true

  has_many :chat_agents, dependent: :destroy
  has_many :agents, through: :chat_agents

  validates :agents, length: { minimum: 1, message: "must include at least one agent" }, if: :manual_responses?

  json_attributes :title_or_default, :model_id, :model_label, :ai_model_name, :updated_at_formatted,
                  :updated_at_short, :message_count, :web_access, :manual_responses, :participants_json,
                  :archived_at, :discarded_at, :archived, :discarded, :respondable do |hash, options|
    # For sidebar format, only include minimal attributes
    if options&.dig(:as) == :sidebar_json
      hash.slice!("id", "title_or_default", "updated_at_short")
    end
    hash
  end

  broadcasts_to :account

  # Custom validation since model_id is resolved in before_save
  validate :model_must_be_present

  # All models go through OpenRouter
  after_initialize :configure_for_openrouter

  after_create_commit -> { GenerateTitleJob.perform_later(self) }, unless: :title?

  # Scopes for archive and discard functionality
  scope :kept, -> { undiscarded }
  scope :archived, -> { where.not(archived_at: nil) }
  scope :active, -> { where(archived_at: nil) }

  # Available AI models grouped by category
  # Model IDs from OpenRouter API: https://openrouter.ai/api/v1/models
  MODELS = [
    # Top Models - Flagship from each major provider
    {
      model_id: "openai/gpt-5.2",
      label: "GPT-5.2",
      group: "Top Models",
      thinking: { supported: true }
    },
    {
      model_id: "anthropic/claude-opus-4.5",
      label: "Claude Opus 4.5",
      group: "Top Models",
      thinking: { supported: true, requires_direct_api: true, provider_model_id: "claude-opus-4-5-20251101" }
    },
    {
      model_id: "google/gemini-3-pro-preview",
      label: "Gemini 3 Pro",
      group: "Top Models",
      thinking: { supported: true }
    },
    { model_id: "x-ai/grok-4.1-fast", label: "Grok 4.1 Fast", group: "Top Models" },
    { model_id: "deepseek/deepseek-v3.2", label: "DeepSeek V3.2", group: "Top Models" },

    # OpenAI
    { model_id: "openai/gpt-5.1", label: "GPT-5.1", group: "OpenAI", thinking: { supported: true } },
    { model_id: "openai/gpt-5", label: "GPT-5", group: "OpenAI", thinking: { supported: true } },
    { model_id: "openai/gpt-5-mini", label: "GPT-5 Mini", group: "OpenAI" },
    { model_id: "openai/gpt-5-nano", label: "GPT-5 Nano", group: "OpenAI" },
    { model_id: "openai/o3", label: "O3", group: "OpenAI" },
    { model_id: "openai/o3-mini", label: "O3 Mini", group: "OpenAI" },
    { model_id: "openai/o4-mini-high", label: "O4 Mini High", group: "OpenAI" },
    { model_id: "openai/o4-mini", label: "O4 Mini", group: "OpenAI" },
    { model_id: "openai/o1", label: "O1", group: "OpenAI" },
    { model_id: "openai/gpt-4.1", label: "GPT-4.1", group: "OpenAI" },
    { model_id: "openai/gpt-4.1-mini", label: "GPT-4.1 Mini", group: "OpenAI" },
    { model_id: "openai/gpt-4o", label: "GPT-4o", group: "OpenAI" },
    { model_id: "openai/gpt-4o-mini", label: "GPT-4o Mini", group: "OpenAI" },

    # Anthropic
    {
      model_id: "anthropic/claude-sonnet-4.5",
      label: "Claude Sonnet 4.5",
      group: "Anthropic",
      thinking: { supported: true, requires_direct_api: true, provider_model_id: "claude-sonnet-4-5-20251201" }
    },
    { model_id: "anthropic/claude-haiku-4.5", label: "Claude Haiku 4.5", group: "Anthropic" },
    {
      model_id: "anthropic/claude-opus-4",
      label: "Claude Opus 4",
      group: "Anthropic",
      thinking: { supported: true, requires_direct_api: true, provider_model_id: "claude-opus-4-20250514" }
    },
    {
      model_id: "anthropic/claude-sonnet-4",
      label: "Claude Sonnet 4",
      group: "Anthropic",
      thinking: { supported: true, requires_direct_api: true, provider_model_id: "claude-sonnet-4-20250514" }
    },
    {
      model_id: "anthropic/claude-3.7-sonnet",
      label: "Claude 3.7 Sonnet",
      group: "Anthropic",
      thinking: { supported: true }
    },
    { model_id: "anthropic/claude-3.5-sonnet", label: "Claude 3.5 Sonnet", group: "Anthropic" },
    { model_id: "anthropic/claude-3-opus", label: "Claude 3 Opus", group: "Anthropic" },

    # Google
    { model_id: "google/gemini-3-flash-preview", label: "Gemini 3 Flash", group: "Google" },
    { model_id: "google/gemini-2.5-pro", label: "Gemini 2.5 Pro", group: "Google" },
    { model_id: "google/gemini-2.5-flash", label: "Gemini 2.5 Flash", group: "Google" },

    # xAI
    { model_id: "x-ai/grok-4-fast", label: "Grok 4 Fast", group: "xAI" },
    { model_id: "x-ai/grok-4", label: "Grok 4", group: "xAI" },
    { model_id: "x-ai/grok-3", label: "Grok 3", group: "xAI" },

    # DeepSeek
    { model_id: "deepseek/deepseek-r1", label: "DeepSeek R1", group: "DeepSeek" },
    { model_id: "deepseek/deepseek-v3", label: "DeepSeek V3", group: "DeepSeek" }
  ].freeze

  def self.model_config(model_id)
    MODELS.find { |m| m[:model_id] == model_id }
  end

  def self.supports_thinking?(model_id)
    model_config(model_id)&.dig(:thinking, :supported) == true
  end

  def self.requires_direct_api_for_thinking?(model_id)
    model_config(model_id)&.dig(:thinking, :requires_direct_api) == true
  end

  def self.provider_model_id(model_id)
    model_config(model_id)&.dig(:thinking, :provider_model_id) || model_id.to_s.sub(%r{^.+/}, "")
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

  def title_or_default
    title.presence || "New Conversation"
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
      end

      forked
    end
  end

  def build_context_for_agent(agent)
    [ system_message_for(agent) ] + messages_context_for(agent)
  end

  private

  def configure_for_openrouter
    # All models go through OpenRouter, so we always use that provider
    # and assume the model exists (since our MODELS list is curated for OpenRouter)
    self.provider = :openrouter
    self.assume_model_exists = true

    # Set default model if none specified (check all possible sources)
    unless @model_string.present? || ai_model.present? || model_id_string.present?
      self.model_id = "openrouter/auto"
    end
  end

  def model_must_be_present
    if @model_string.blank? && ai_model.blank? && model_id_string.blank?
      errors.add(:model_id, "can't be blank")
    end
  end

  # Group chat context building helpers
  def system_message_for(agent)
    parts = []

    parts << (agent.system_prompt.presence || "You are #{agent.name}.")

    if (memory_context = agent.memory_context)
      parts << memory_context
    end

    if (whiteboard_index = whiteboard_index_context)
      parts << whiteboard_index
    end

    if (active_board = active_whiteboard_context)
      parts << active_board
    end

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

  def messages_context_for(agent)
    messages.includes(:user, :agent).order(:created_at)
      .reject { |msg| msg.content.blank? }  # Filter out empty messages (e.g., before tool calls)
      .map { |msg| format_message_for_context(msg, agent) }
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

  def format_message_for_context(message, current_agent)
    text_content = if message.agent_id == current_agent.id
      message.content
    elsif message.agent_id.present?
      "[#{message.agent.name}]: #{message.content}"
    else
      name = message.user&.full_name.presence || message.user&.email_address&.split("@")&.first || "User"
      "[#{name}]: #{message.content}"
    end

    role = message.agent_id == current_agent.id ? "assistant" : "user"

    # Include file attachments if present using RubyLLM::Content
    file_paths = message.file_paths_for_llm
    content = if file_paths.present?
      RubyLLM::Content.new(text_content, file_paths)
    else
      text_content
    end

    { role: role, content: content }
  end

end
