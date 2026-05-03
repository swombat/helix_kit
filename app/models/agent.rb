class Agent < ApplicationRecord

  include ActionView::Helpers::DateHelper
  include Broadcastable
  include ObfuscatesId
  include JsonAttributes
  include SyncAuthorizable
  include TelegramNotifiable
  include Agent::Initiation
  include Agent::Memory
  include Agent::Predecessor
  include Agent::Tools

  belongs_to :account
  has_many :chat_agents, dependent: :destroy
  has_many :chats, through: :chat_agents

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
  validates :summary_prompt, length: { maximum: 10_000 }
  validates :refinement_prompt, length: { maximum: 10_000 }
  validates :colour, inclusion: { in: VALID_COLOURS }, allow_nil: true
  validates :icon, inclusion: { in: VALID_ICONS }, allow_nil: true
  validates :thinking_budget,
            numericality: { greater_than_or_equal_to: 1000, less_than_or_equal_to: 50000 },
            allow_nil: true
  validates :refinement_threshold,
            numericality: { greater_than: 0, less_than_or_equal_to: 1 },
            allow_nil: true
  broadcasts_to :account

  scope :active, -> { where(active: true) }
  scope :unpaused, -> { where(paused: false) }
  scope :by_name, -> { order(:name) }

  json_attributes :name, :system_prompt, :reflection_prompt, :memory_reflection_prompt,
                  :summary_prompt, :refinement_prompt, :refinement_threshold,
                  :model_id, :model_label, :enabled_tools, :active?, :paused?, :colour, :icon,
                  :memories_count, :memory_token_summary, :thinking_enabled, :thinking_budget,
                  :telegram_bot_username, :telegram_configured?,
                  :voiced?, :voice_id

  def self.json_attrs_for(options = nil)
    return json_attrs unless options&.dig(:as) == :list

    json_attrs - [ :memories_count, :memory_token_summary ]
  end

  def model_label
    Chat::MODELS.find { |m| m[:model_id] == model_id }&.dig(:label) || model_id
  end

  def uses_thinking?
    thinking_enabled? && Chat.supports_thinking?(model_id)
  end

  def voiced?
    voice_id.present?
  end

  def other_conversation_summaries(exclude_chat_id:)
    chat_agents
      .joins(:chat)
      .where.not(chat_id: exclude_chat_id)
      .where.not(agent_summary: [ nil, "" ])
      .where("chats.updated_at > ?", 6.hours.ago)
      .merge(Chat.kept)
      .includes(:chat)
      .order("chats.updated_at DESC")
      .limit(10)
  end

end
