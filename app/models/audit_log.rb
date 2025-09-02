class AuditLog < ApplicationRecord

  belongs_to :user, optional: true
  belongs_to :account, optional: true
  belongs_to :auditable, polymorphic: true, optional: true

  validates :action, presence: true

  scope :recent, -> { order(created_at: :desc) }
  scope :for_account, ->(account) { where(account: account) }
  scope :for_user, ->(user) { where(user: user) }

  def display_action
    action.to_s.humanize
  end

end
