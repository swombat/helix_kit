class User < ApplicationRecord

  include Confirmable

  has_secure_password validations: false
  has_many :sessions, dependent: :destroy

  # Account associations
  has_many :account_users, dependent: :destroy
  has_many :accounts, through: :account_users
  belongs_to :default_account, class_name: "Account", optional: true
  has_one :personal_account_user, -> { joins(:account).where(accounts: { account_type: 0 }) },
          class_name: "AccountUser"
  has_one :personal_account, through: :personal_account_user, source: :account

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  validates :email_address, presence: true,
    uniqueness: { case_sensitive: false },
    format: { with: URI::MailTo::EMAIL_REGEXP }

  validates :password, confirmation: true,
    length: { in: 6..72 },
    if: :password_digest_changed?

  validates :password, presence: true, on: :update, if: :confirmed?

  before_create :generate_confirmation_token
  after_create :ensure_account_user_exists

  generates_token_for :password_reset, expires_in: 2.hours do
    password_salt&.last(10)
  end

  generates_token_for :email_confirmation, expires_in: 24.hours do
    email_address
  end

  def self.find_by_password_reset_token!(token)
    user = find_by_token_for(:password_reset, token)
    raise(ActiveSupport::MessageVerifier::InvalidSignature) unless user
    user
  end

  def self.find_by_confirmation_token!(token)
    find_by!(confirmation_token: token)
  rescue ActiveRecord::RecordNotFound
    raise ActiveSupport::MessageVerifier::InvalidSignature
  end

  def password_reset_token
    generate_token_for(:password_reset)
  end

  def send_confirmation_email
    mail = UserMailer.confirmation(self)
    Rails.env.development? ? mail.deliver_now : mail.deliver_later
  end

  # Business Logic Methods (not in a service!)
  def self.register!(email)
    transaction do
      user = find_or_initialize_by(email_address: email)
      was_new_user = !user.persisted?

      if user.persisted?
        # Existing user - find or create their membership
        user.find_or_create_membership!

        # If the user is not confirmed, regenerate confirmation token for resend
        if !user.confirmed?
          user.generate_confirmation_token
          user.save!(validate: false)

          # Also update the AccountUser token if it exists
          account_user = user.account_users.first
          if account_user && !account_user.confirmed?
            account_user.update!(
              confirmation_token: user.confirmation_token,
              confirmation_sent_at: user.confirmation_sent_at
            )
          end
        end
      else
        # New user - validate email first, then create with account
        # Only validate email_address, skip password validation
        user.valid?
        if user.errors[:email_address].any?
          raise ActiveRecord::RecordInvalid.new(user)
        end

        user.save!(validate: false) # Skip all other validations
        # The after_create callback will have created an AccountUser
        # Just ensure the confirmation token is transferred
        account_user = user.account_users.first
        if account_user && account_user.confirmation_token != user.confirmation_token
          account_user.update!(
            confirmation_token: user.confirmation_token,
            confirmation_sent_at: user.confirmation_sent_at,
            confirmed_at: user.confirmed_at
          )
          # Clear User's confirmation token since it's now on AccountUser
          user.update(confirmation_token: nil)
        end
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

    # If the user is already confirmed, create confirmed AccountUser
    # If not, create unconfirmed AccountUser
    account_users.create!(
      account: account,
      role: "owner",
      confirmed_at: confirmed_at, # Use existing confirmation timestamp
      confirmation_token: confirmed_at? ? nil : confirmation_token,
      confirmation_sent_at: confirmed_at? ? nil : confirmation_sent_at
    )
  end

  def can_login?
    confirmed? && password_digest?
  end

  # Authorization helpers
  def member_of?(account)
    account_users.confirmed.where(account: account).exists?
  end

  def can_manage?(account)
    account_users.confirmed.admins.where(account: account).exists?
  end

  def owns?(account)
    account_users.confirmed.owners.where(account: account).exists?
  end

  private

  def ensure_account_user_exists
    # For backward compatibility - ensure any User created gets an AccountUser
    return if account_users.exists?

    account = Account.create!(
      name: "My Account",
      account_type: :personal
    )

    # Create AccountUser with same confirmation data as User
    account_users.create!(
      account: account,
      role: "owner",
      confirmation_token: confirmation_token,
      confirmation_sent_at: confirmation_sent_at,
      confirmed_at: confirmed_at,
      skip_confirmation: confirmed_at.present?  # Only skip email if already confirmed
    )

    # Set as default account
    update(default_account_id: account.id)
  end

end
