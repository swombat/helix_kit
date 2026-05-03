module Chat::Archivable

  extend ActiveSupport::Concern

  included do
    scope :kept, -> { undiscarded }
    scope :archived, -> { where.not(archived_at: nil) }
    scope :active, -> { where(archived_at: nil) }
  end

  def archive!
    update!(archived_at: Time.current)
  end

  def unarchive!
    update!(archived_at: nil)
  end

  def archived?
    archived_at.present?
  end

  def archived
    archived?
  end

  def discarded
    discarded?
  end

  def respondable?
    !archived? && !discarded?
  end

  def respondable
    respondable?
  end

end
