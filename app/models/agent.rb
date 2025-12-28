class Agent < ApplicationRecord

  include Broadcastable
  include ObfuscatesId
  include JsonAttributes
  include SyncAuthorizable

  belongs_to :account
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
  validate :enabled_tools_must_be_valid

  broadcasts_to :account

  scope :active, -> { where(active: true) }
  scope :by_name, -> { order(:name) }

  json_attributes :name, :system_prompt, :reflection_prompt, :memory_reflection_prompt, :model_id, :model_label,
                  :enabled_tools, :active?, :colour, :icon, :memories_count

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

end
