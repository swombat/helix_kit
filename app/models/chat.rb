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
    [ "openrouter/auto", "Auto (Recommended)" ],
    [ "openai/gpt-4o-mini", "GPT-4 Mini" ],
    [ "anthropic/claude-3.7-sonnet", "Claude 3.7 Sonnet" ],
    [ "google/gemini-2.5-pro-preview-03-25", "Gemini 2.5 Pro" ]
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
    MODELS.find { |m| m[0] == model_id }&.last
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
