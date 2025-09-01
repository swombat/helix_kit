class Account < ApplicationRecord

  include JsonAttributes
  include SyncAuthorizable
  include Broadcastable

  # Broadcasting configuration
  broadcasts_to :all # Admin collection

  # Enums
  enum :account_type, { personal: 0, team: 1 }

  # Associations
  has_many :account_users, dependent: :destroy
  has_many :users, through: :account_users
  has_one :owner_membership, -> { where(role: "owner") },
          class_name: "AccountUser"
  has_one :owner, through: :owner_membership, source: :user

  # Validations (Rails-only, no SQL constraints!)
  validates :name, presence: true
  validates :account_type, presence: true
  validate :enforce_personal_account_limit, if: :personal?
  validate :can_invite_members, if: -> { account_users.any?(&:invitation?) }

  # Callbacks
  before_validation :set_default_name, on: :create
  before_validation :generate_slug, on: :create
  before_destroy :mark_account_users_for_skip_check, prepend: true

  # Scopes
  scope :personal, -> { where(account_type: :personal) }
  scope :team, -> { where(account_type: :team) }

  # Authorization scope for SyncChannel - Account is special, it IS the account
  def self.accessible_by(user)
    return none unless user
    return all if user.site_admin
    user.accounts
  end

  json_attributes :personal?, :team?, :active?, :is_site_admin, :name

  # Business Logic Methods
  def add_user!(user, role: "member", skip_confirmation: false)
    account_user = account_users.find_or_initialize_by(user: user)

    if account_user.persisted?
      account_user.resend_confirmation! unless account_user.confirmed?
      account_user
    else
      account_user.role = role
      account_user.skip_confirmation = skip_confirmation
      account_user.save!
      account_user
    end
  end

  # Business Logic for Invitations
  def invite_member(email:, role:, invited_by:)
    account_users.build(
      user: User.find_or_invite(email),
      role: role,
      invited_by: invited_by
    )
  end

  def last_owner?
    account_users.owners.confirmed.count == 1
  end

  def members_count
    account_users.confirmed.count
  end

  def active?
    members_count > 0
  end

  def pending_invitations_count
    account_users.pending_invitations.count
  end

  # Association with proper includes for N+1 prevention
  def members_with_details
    account_users.includes(:user, :invited_by).order(:created_at)
  end

  def personal_account_for?(user)
    personal? && owner == user
  end

  def make_personal!
    return unless team? && account_users.count == 1
    update!(account_type: :personal)
    account_users.first.update!(role: :owner)
  end

  def make_team!(name)
    return unless personal?
    update!(account_type: :team, name: name)
  end

  def can_be_personal?
    team? && account_users.count == 1
  end

  def name
    if personal? && owner&.full_name.present?
      "#{owner.full_name}'s Account"
    else
      super()
    end
  end

  def users_count
    account_users.count
  end

  def members_count
    account_users.confirmed.count
  end

  alias_method :active, :active?

  private

  def enforce_personal_account_limit
    if personal? && account_users.count > 1
      errors.add(:base, "Personal accounts can only have one user")
    end
  end

  def can_invite_members
    errors.add(:base, "Personal accounts cannot invite members") if personal?
  end

  def set_default_name
    self.name ||= "Account #{SecureRandom.hex(4)}"
  end

  def generate_slug
    self.slug ||= name.parameterize if name.present?

    # Ensure uniqueness
    if Account.exists?(slug: slug)
      self.slug = "#{slug}-#{SecureRandom.hex(4)}"
    end
  end

  def mark_account_users_for_skip_check
    account_users.each { |au| au.skip_owner_check = true }
  end

end
