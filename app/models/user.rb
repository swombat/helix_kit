class User < ApplicationRecord

  has_secure_password validations: false

  # User preferences stored as JSON
  store_accessor :preferences, :theme
  has_many :sessions, dependent: :destroy

  # Account associations
  has_many :account_users, dependent: :destroy
  has_many :accounts, through: :account_users
  has_one :personal_account_user, -> { joins(:account).where(accounts: { account_type: 0 }) },
          class_name: "AccountUser"
  has_one :personal_account, through: :personal_account_user, source: :account

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

  validates_presence_of :first_name, :last_name, on: :update, if: -> { confirmed? }

  after_create :ensure_account_user_exists
  after_initialize :set_default_theme, if: :new_record?

  generates_token_for :password_reset, expires_in: 2.hours do
    password_salt&.last(10)
  end

  def self.find_by_password_reset_token!(token)
    user = find_by_token_for(:password_reset, token)
    raise(ActiveSupport::MessageVerifier::InvalidSignature) unless user
    user
  end

  def password_reset_token
    generate_token_for(:password_reset)
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

  # Clean authorization methods
  def can_manage?(account)
    account_users.confirmed.admins.exists?(account: account)
  end

  def owns?(account)
    account_users.confirmed.owners.exists?(account: account)
  end

  def member_of?(account)
    account_users.confirmed.exists?(account: account)
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
    "#{first_name} #{last_name}".strip.presence || email_address
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

  def as_json(options = {})
    super(options.merge(methods: [ :full_name, :site_admin ]))
  end

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
