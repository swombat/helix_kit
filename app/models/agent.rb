class Agent < ApplicationRecord

  include Broadcastable
  include ObfuscatesId
  include JsonAttributes
  include SyncAuthorizable

  belongs_to :account

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
  validates :colour, inclusion: { in: VALID_COLOURS }, allow_nil: true
  validates :icon, inclusion: { in: VALID_ICONS }, allow_nil: true
  validate :enabled_tools_must_be_valid

  broadcasts_to :account

  scope :active, -> { where(active: true) }
  scope :by_name, -> { order(:name) }

  json_attributes :name, :system_prompt, :model_id, :model_label,
                  :enabled_tools, :active?, :colour, :icon

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

end
