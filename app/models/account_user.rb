# app/models/account_user.rb
class AccountUser < ApplicationRecord

  include Confirmable

  # Constants
  ROLES = %w[owner admin member].freeze

  # Attributes
  attr_accessor :skip_confirmation

  # Associations
  belongs_to :account
  belongs_to :user
  belongs_to :invited_by, class_name: "User", optional: true

  # Validations (Rails-only!)
  validates :role, inclusion: { in: ROLES }
  validates :user_id, uniqueness: {
    scope: :account_id,
    message: "is already a member of this account"
  }
  validate :enforce_personal_account_role
  validate :enforce_single_owner_per_personal_account

  # Callbacks
  after_create_commit :send_confirmation_email, unless: :skip_confirmation
  after_create :set_user_default_account

  # Scopes
  scope :owners, -> { where(role: "owner") }
  scope :admins, -> { where(role: [ "owner", "admin" ]) }

  # Class Methods
  def self.confirm_by_token!(token)
    account_user = find_by!(confirmation_token: token)
    account_user.confirm!
    account_user
  rescue ActiveRecord::RecordNotFound
    raise ActiveSupport::MessageVerifier::InvalidSignature
  end

  # Instance Methods
  def owner?
    role == "owner"
  end

  def admin?
    role.in?([ "owner", "admin" ])
  end

  def can_manage?
    owner? || admin?
  end

  def send_confirmation_email
    if invited_by_id.present?
      AccountMailer.team_invitation(self).deliver_later
    else
      AccountMailer.confirmation(self).deliver_later
    end
  end

  private

  def confirmable_attributes_for_token
    "#{account_id}-#{user_id}-#{user.email_address}"
  end

  def enforce_personal_account_role
    if account&.personal? && role != "owner"
      errors.add(:role, "must be owner for personal accounts")
    end
  end

  def enforce_single_owner_per_personal_account
    if account&.personal? && account.account_users.where.not(id: id).exists?
      errors.add(:base, "Personal accounts can only have one user")
    end
  end

  def set_user_default_account
    if user.default_account.nil?
      user.update(default_account_id: account_id)
    end
  end

  def needs_confirmation?
    !skip_confirmation && super
  end

end
