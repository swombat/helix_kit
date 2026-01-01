class Whiteboard < ApplicationRecord

  include Broadcastable
  include ObfuscatesId

  MAX_RECOMMENDED_LENGTH = 10_000

  belongs_to :account
  belongs_to :last_edited_by, polymorphic: true, optional: true

  validates :name, presence: true,
                   length: { maximum: 100 },
                   uniqueness: { scope: :account_id, conditions: -> { active } }
  validates :summary, length: { maximum: 250 }
  validates :content, length: { maximum: 100_000 }

  broadcasts_to :account

  scope :active, -> { where(deleted_at: nil) }
  scope :deleted, -> { where.not(deleted_at: nil) }
  scope :by_name, -> { order(:name) }

  before_save :increment_revision, if: :content_changed?
  after_save :clear_active_references, if: :became_deleted?

  def soft_delete!
    update!(deleted_at: Time.current)
  end

  def restore!
    update!(deleted_at: nil)
  end

  def deleted?
    deleted_at.present?
  end

  def over_recommended_length?
    content.to_s.length > MAX_RECOMMENDED_LENGTH
  end

  def editor_name
    case last_edited_by
    when User then last_edited_by.full_name.presence || last_edited_by.email_address.split("@").first
    when Agent then last_edited_by.name
    end
  end

  private

  def increment_revision
    self.revision = (revision || 0) + 1
    self.last_edited_at = Time.current
  end

  def became_deleted?
    saved_change_to_deleted_at? && deleted?
  end

  def clear_active_references
    Chat.where(active_whiteboard_id: id).update_all(active_whiteboard_id: nil)
  end

end
