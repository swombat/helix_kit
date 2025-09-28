class Chat < ApplicationRecord

  include Broadcastable
  include ObfuscatesId
  include SyncAuthorizable
  include JsonAttributes

  acts_as_chat

  belongs_to :account

  json_attributes :title, :model_id, :ai_model_name, :updated_at_formatted, :message_count

  broadcasts_to :account

  validates :model_id, presence: true

  after_create_commit -> { GenerateTitleJob.perform_later(self) }, unless: :title?

  # Available AI models
  MODELS = [
    { model_id: "openai/gpt-5", label: "GPT-5 (Recommended)" },
    { model_id: "openai/gpt-5-mini", label: "GPT-5 Mini" },
    { model_id: "openai/gpt-5-nano", label: "GPT-5 Nano" },
    { model_id: "openai/gpt-5-chat", label: "GPT-5 Chat" },
    { model_id: "anthropic/claude-sonnet-4", label: "Claude Sonnet 4" },
    { model_id: "anthropic/claude-opus-4", label: "Claude Opus 4" },
    { model_id: "anthropic/claude-3.7-sonnet", label: "Claude 3.7 Sonnet" },
    { model_id: "anthropic/claude-3.7-sonnet:thinking", label: "Claude 3.7 Sonnet (Thinking)" },
    { model_id: "google/gemini-2.5-flash-preview-09-2025", label: "Gemini 2.5 Flash" },
    { model_id: "google/gemini-2.5-pro", label: "Gemini 2.5 Pro" },
    { model_id: "x-ai/grok-4-fast", label: "Grok 4 Fast" },
    { model_id: "x-ai/grok-code-fast-1", label: "Grok Code Fast 1" },
    { model_id: "x-ai/grok-4", label: "Grok 4" },
    { model_id: "qwen/qwen3-max", label: "Qwen 3 Max" },
    { model_id: "moonshotai/kimi-k2-0905", label: "Kimi K2 0905" },
    { model_id: "openai/o1", label: "OpenAI O1" },
    { model_id: "openai/o3", label: "OpenAI O3" },
    { model_id: "openai/o4-mini", label: "OpenAI O4 Mini" },
    { model_id: "openai/o4-mini-high", label: "OpenAI O4 Mini High" },
    { model_id: "openai/gpt-4o-mini", label: "GPT-4 Mini" },
    { model_id: "openai/gpt-4.1", label: "GPT-4.1" },
    { model_id: "openai/gpt-4.1-mini", label: "GPT-4.1 Mini" },
    { model_id: "openai/chatgpt-4o-latest", label: "ChatGPT-4o Latest" }
  ].freeze

  scope :latest, -> { order(updated_at: :desc) }

  # Create chat with optional initial message
  def self.create_with_message!(attributes, message_content: nil, user: nil)
    transaction do
      chat = create!(attributes)
      if message_content.present?
        message = chat.messages.create!(
          content: message_content,
          role: "user",
          user: user
        )
        AiResponseJob.perform_later(chat)
      end
      chat
    end
  end

  def title_or_default
    title.presence || "New Conversation"
  end

  def ai_model_name
    MODELS.find { |m| m[0] == model_id }&.last ||
      case model_id
      when "openrouter/auto"
        "Auto (Recommended)"
      else
        model_id
      end
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

end
