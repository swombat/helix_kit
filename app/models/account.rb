class Account < ApplicationRecord

  include JsonAttributes
  include SyncAuthorizable
  include Broadcastable

  # Broadcasting configuration
  broadcasts_to :all # Admin collection
  skip_broadcasts_on_destroy :memberships

  # Enums
  enum :account_type, { personal: 0, team: 1 }

  # Associations
  has_many :memberships, dependent: :destroy
  has_many :users, through: :memberships
  has_one :owner_membership, -> { where(role: "owner") },
          class_name: "Membership"
  has_one :owner, through: :owner_membership, source: :user
  has_many :chats, dependent: :destroy
  has_many :agents, dependent: :destroy

  # Validations (Rails-only, no SQL constraints!)
  validates :name, presence: true
  validates :account_type, presence: true
  validate :enforce_personal_account_limit, if: :personal?
  validate :can_invite_members, if: -> { memberships.any?(&:invitation?) }

  # Callbacks
  before_validation :set_default_name, on: :create
  before_validation :generate_slug, on: :create
  before_destroy :mark_memberships_for_skip_check, prepend: true

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
    membership = memberships.find_or_initialize_by(user: user)

    if membership.persisted?
      membership.resend_confirmation! unless membership.confirmed?
      membership
    else
      membership.role = role
      membership.skip_confirmation = skip_confirmation
      membership.save!
      membership
    end
  end

  # Business Logic for Invitations
  def invite_member(email:, role:, invited_by:)
    memberships.build(
      user: User.find_or_invite(email),
      role: role,
      invited_by: invited_by
    )
  end

  def last_owner?
    memberships.owners.confirmed.count == 1
  end

  def members_count
    memberships.confirmed.count
  end

  def active?
    members_count > 0
  end

  def pending_invitations_count
    memberships.pending_invitations.count
  end

  # Association with proper includes for N+1 prevention
  def members_with_details
    memberships.includes(:user, :invited_by).order(:created_at)
  end

  def personal_account_for?(user)
    personal? && owner == user
  end

  def make_personal!
    return unless team? && memberships.count == 1
    update!(account_type: :personal)
    memberships.first.update!(role: :owner)
  end

  def make_team!(name)
    return unless personal?
    update!(account_type: :team, name: name)
  end

  def can_be_personal?
    team? && memberships.count == 1
  end

  def name
    if personal? && owner&.full_name.present?
      "#{owner.full_name}'s Account"
    else
      super()
    end
  end

  def users_count
    memberships.count
  end

  def members_count
    memberships.confirmed.count
  end

  alias_method :active, :active?

  # Authorization methods - following DHH's "fat models, skinny controllers" principle
  def manageable_by?(user)
    return false unless user
    return true if user.site_admin
    memberships.confirmed.admins.exists?(user: user)
  end

  def owned_by?(user)
    return false unless user
    return true if user.site_admin
    memberships.confirmed.owners.exists?(user: user)
  end

  def accessible_by?(user)
    return false unless user
    return true if user.site_admin
    memberships.confirmed.exists?(user: user)
  end

  # Custom error for authorization failures
  class NotAuthorized < StandardError; end

  private

  def enforce_personal_account_limit
    if personal? && memberships.count > 1
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

  def mark_memberships_for_skip_check
    memberships.each { |m| m.skip_owner_check = true }
  end

end
