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
  before_create :auto_confirm_if_skip_confirmation
  after_create_commit :send_confirmation_email, unless: :skip_confirmation

  # Scopes
  scope :owners, -> { where(role: "owner") }
  scope :admins, -> { where(role: [ "owner", "admin" ]) }

  # Class Methods
  def self.confirm_by_token!(token)
    raise ActiveSupport::MessageVerifier::InvalidSignature if token.nil?

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

  def auto_confirm_if_skip_confirmation
    self.confirmed_at = Time.current if skip_confirmation
  end

  def confirmable_attributes_for_token
    "#{account_id}-#{user_id}-#{user.email_address}"
  end

  def enforce_personal_account_role
    errors.add(:role, "must be owner for personal accounts") if account&.personal? && role != "owner"
  end

  def enforce_single_owner_per_personal_account
    errors.add(:base, "Personal accounts can only have one user") if account&.personal? && account.account_users.where.not(id: id).exists?
  end

  def needs_confirmation?
    !skip_confirmation && super
  end

end
