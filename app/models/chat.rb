class Chat < ApplicationRecord

  include Broadcastable
  include ObfuscatesId
  include SyncAuthorizable
  include JsonAttributes

  acts_as_chat model: :ai_model, model_class: "AiModel", model_foreign_key: :ai_model_id

  belongs_to :account

  json_attributes :title_or_default, :model_id, :ai_model_name, :updated_at_formatted, :updated_at_short, :message_count, :can_fetch_urls do |hash, options|
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

  # Available AI models grouped by category
  MODELS = [
    # Top Models - Flagship from each major provider
    { model_id: "openai/gpt-5.2-20251211", label: "GPT-5.2", group: "Top Models" },
    { model_id: "anthropic/claude-4.5-opus-20251124", label: "Claude Opus 4.5", group: "Top Models" },
    { model_id: "google/gemini-3-pro-preview-20251117", label: "Gemini 3 Pro", group: "Top Models" },
    { model_id: "x-ai/grok-4.1-fast", label: "Grok 4.1", group: "Top Models" },
    { model_id: "deepseek/deepseek-v3.2-20251201", label: "DeepSeek V3.2", group: "Top Models" },

    # OpenAI
    { model_id: "openai/gpt-5.1-20251113", label: "GPT-5.1", group: "OpenAI" },
    { model_id: "openai/gpt-5", label: "GPT-5", group: "OpenAI" },
    { model_id: "openai/gpt-5-mini", label: "GPT-5 Mini", group: "OpenAI" },
    { model_id: "openai/gpt-5-nano", label: "GPT-5 Nano", group: "OpenAI" },
    { model_id: "openai/gpt-5-chat", label: "GPT-5 Chat", group: "OpenAI" },
    { model_id: "openai/o3", label: "O3", group: "OpenAI" },
    { model_id: "openai/o4-mini-high", label: "O4 Mini High", group: "OpenAI" },
    { model_id: "openai/o4-mini", label: "O4 Mini", group: "OpenAI" },
    { model_id: "openai/o1", label: "O1", group: "OpenAI" },
    { model_id: "openai/gpt-4.1", label: "GPT-4.1", group: "OpenAI" },
    { model_id: "openai/gpt-4.1-mini", label: "GPT-4.1 Mini", group: "OpenAI" },
    { model_id: "openai/gpt-4o-mini", label: "GPT-4o Mini", group: "OpenAI" },
    { model_id: "openai/chatgpt-4o-latest", label: "ChatGPT-4o Latest", group: "OpenAI" },

    # Anthropic
    { model_id: "anthropic/claude-4.5-sonnet-20250929", label: "Claude Sonnet 4.5", group: "Anthropic" },
    { model_id: "anthropic/claude-4.5-haiku-20251001", label: "Claude Haiku 4.5", group: "Anthropic" },
    { model_id: "anthropic/claude-opus-4", label: "Claude Opus 4", group: "Anthropic" },
    { model_id: "anthropic/claude-sonnet-4", label: "Claude Sonnet 4", group: "Anthropic" },
    { model_id: "anthropic/claude-3.7-sonnet", label: "Claude 3.7 Sonnet", group: "Anthropic" },
    { model_id: "anthropic/claude-3.7-sonnet:thinking", label: "Claude 3.7 Sonnet (Thinking)", group: "Anthropic" },
    { model_id: "anthropic/claude-3-opus", label: "Claude Opus 3", group: "Anthropic" },

    # Google
    { model_id: "google/gemini-3-flash-preview-20251217", label: "Gemini 3 Flash", group: "Google" },
    { model_id: "google/gemini-2.5-pro", label: "Gemini 2.5 Pro", group: "Google" },
    { model_id: "google/gemini-2.5-flash-preview-09-2025", label: "Gemini 2.5 Flash", group: "Google" },

    # xAI
    { model_id: "x-ai/grok-4-fast", label: "Grok 4 Fast", group: "xAI" },
    { model_id: "x-ai/grok-4", label: "Grok 4", group: "xAI" },
    { model_id: "x-ai/grok-code-fast-1", label: "Grok Code Fast 1", group: "xAI" },

    # Other
    { model_id: "qwen/qwen3-max", label: "Qwen 3 Max", group: "Other" },
    { model_id: "moonshotai/kimi-k2-0905", label: "Kimi K2", group: "Other" }
  ].freeze

  scope :latest, -> { order(updated_at: :desc) }

  # Create chat with optional initial message
  def self.create_with_message!(attributes, message_content: nil, user: nil, files: nil)
    transaction do
      chat = create!(attributes)
      if message_content.present? || (files.present? && files.any?)
        message = chat.messages.create!({
          content: message_content || "",
          role: "user",
          user: user,
          skip_content_validation: message_content.blank? && files.present? && files.any? # Skip content validation if we have files but no content
        })
        message.attachments.attach(files) if files.present? && files.any?
        AiResponseJob.perform_later(chat)
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

  def model_name
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

  # Configure tools for RubyLLM based on settings
  def available_tools
    return [] unless can_fetch_urls?
    [ WebFetchTool ]
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

end
