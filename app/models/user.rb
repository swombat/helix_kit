class User < ApplicationRecord

  include JsonAttributes
  include SyncAuthorizable
  include Broadcastable

  has_secure_password validations: false

  # Avatar attachment
  has_one_attached :avatar do |attachable|
    attachable.variant :thumb, resize_to_fill: [ 100, 100 ]
    attachable.variant :medium, resize_to_fill: [ 300, 300 ]
  end

  # User preferences stored as JSON
  store_accessor :preferences, :theme
  has_many :sessions, dependent: :destroy

  # Account associations
  has_many :account_users, dependent: :destroy
  has_many :accounts, through: :account_users
  has_one :personal_account_user, -> { joins(:account).where(accounts: { account_type: 0 }) },
          class_name: "AccountUser"
  has_one :personal_account, through: :personal_account_user, source: :account

  # Broadcasting configuration - automatically broadcasts to all associated accounts
  broadcasts_to :accounts

  normalizes :email_address, with: ->(e) { e.strip.downcase }
  normalizes :first_name, with: ->(name) { name&.strip }
  normalizes :last_name, with: ->(name) { name&.strip }

  validates :email_address, presence: true,
    uniqueness: { case_sensitive: false },
    format: { with: URI::MailTo::EMAIL_REGEXP }

  # Conditional password validation
  # Only validate password if it's being set (present) and user wasn't created via invitation
  validates :password, presence: true, length: { minimum: 8 }, if: -> { password.present? }, unless: :created_via_invitation?
  validates :password, confirmation: true, length: { in: 6..72 }, if: :password_digest_changed?

  validates :timezone, inclusion: { in: ActiveSupport::TimeZone.all.map(&:name) },
    allow_blank: true

  validates :theme, inclusion: { in: %w[light dark system] }, allow_nil: true

  # Avatar validations
  validates :avatar, content_type: [ "image/png", "image/jpeg", "image/gif", "image/webp" ],
                     size: { less_than: 5.megabytes }

  validates_presence_of :first_name, :last_name, on: :update, if: -> { confirmed? }

  after_create :ensure_account_user_exists
  after_initialize :set_default_theme, if: :new_record?

  json_attributes :full_name, :site_admin, :avatar_url, :initials, except: [ :password_digest, :password_reset_token, :password_reset_sent_at ]

  # Use Rails' built-in secure token for password resets
  has_secure_token :password_reset_token

  def send_password_reset
    regenerate_password_reset_token
    update_column(:password_reset_sent_at, Time.current)
    PasswordsMailer.reset(self).deliver_later
  end

  # Override to return the actual stored token, not Rails 8's virtual token
  def password_reset_token_for_url
    read_attribute(:password_reset_token)
  end

  def password_reset_expired?
    return true unless password_reset_sent_at
    password_reset_sent_at < 2.hours.ago
  end

  def clear_password_reset_token!
    update_columns(password_reset_token: nil, password_reset_sent_at: nil)
  end

  # Confirmation is now handled entirely by AccountUser
  def confirmed?
    # A user is confirmed if they have at least one confirmed account membership
    account_users.confirmed.any?
  end

  # Business Logic Methods (not in a service!)
  def self.register!(email)
    transaction do
      user = find_or_initialize_by(email_address: email)
      was_new_user = !user.persisted?

      if user.persisted?
        # Existing user - find or create their membership
        account_user = user.find_or_create_membership!

        # If the user is not confirmed, resend confirmation
        if !user.confirmed?
          account_user.resend_confirmation!
        end
      else
        # New user - validate email first, then create
        user.valid?
        if user.errors[:email_address].any?
          raise ActiveRecord::RecordInvalid.new(user)
        end

        user.save!(validate: false) # Skip password validation
        # The after_create callback will have created an AccountUser with confirmation
      end

      # Add a method to track if this was a new user
      user.define_singleton_method(:was_new_record?) { was_new_user }
      user
    end
  end

  def find_or_create_membership!
    # For existing users, ensure they have an account
    return personal_account_user if personal_account_user&.persisted?

    # Create personal account if missing
    account = Account.create!(
      name: "#{email_address}'s Account",
      account_type: :personal
    )

    # Create unconfirmed AccountUser
    account_users.create!(
      account: account,
      role: "owner"
    )
  end

  def can_login?
    confirmed? && password_digest?
  end

  # Check if user was created via invitation and hasn't set up their account yet
  # These users don't require a password until they confirm their account
  def created_via_invitation?
    account_users.any?(&:invitation?) && !confirmed?
  end

  def default_account
    account_users.confirmed.first&.account || account_users.first&.account
  end

  def full_name
    "#{first_name} #{last_name}".strip.presence
  end

  # Avatar methods
  def avatar_url
    return nil unless avatar.attached?

    if avatar.variable?
      Rails.application.routes.url_helpers.rails_representation_url(
        avatar.variant(resize_to_fill: [ 200, 200 ]),
        only_path: true
      )
    else
      Rails.application.routes.url_helpers.rails_blob_url(avatar, only_path: true)
    end
  end

  def initials
    return "?" unless full_name.present?
    full_name.split.map(&:first).first(2).join.upcase
  end

  # For finding or creating invited users
  def self.find_or_invite(email_address)
    user = find_by(email_address: email_address)
    return user if user

    # Create user without validation (no password required for invitations)
    user = new(email_address: email_address)
    user.save!(validate: false)
    user
  end

  def site_admin
    return true if is_site_admin

    accounts.where(is_site_admin: true).exists?
  end

  # Alias for site_admin method to match common Rails pattern
  alias_method :is_site_admin?, :site_admin

  private

  def set_default_theme
    self.theme ||= "system"
  end

  def ensure_account_user_exists
    # Ensure any User created gets an AccountUser
    return if account_users.exists?

    account = Account.create!(
      name: "#{email_address}'s Account",
      account_type: :personal
    )

    # Create unconfirmed AccountUser (will send confirmation email)
    account_users.create!(
      account: account,
      role: "owner"
    )
  end

end
