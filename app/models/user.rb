class User < ApplicationRecord

  has_secure_password validations: false
  has_many :sessions, dependent: :destroy

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  validates :email_address, presence: true,
    uniqueness: { case_sensitive: false },
    format: { with: URI::MailTo::EMAIL_REGEXP }

  validates :password, confirmation: true,
    length: { in: 6..72 },
    if: :password_digest_changed?

  validates :password, presence: true, on: :update, if: :confirmed?

  before_create :generate_confirmation_token

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

  def confirmed?
    confirmed_at?
  end

  def confirm!
    touch(:confirmed_at)
    update_column(:confirmation_token, nil)
  end

  def generate_confirmation_token
    self.confirmation_token = generate_token_for(:email_confirmation)
    self.confirmation_sent_at = Time.current
  end

  def send_confirmation_email
    mail = UserMailer.confirmation(self)
    Rails.env.development? ? mail.deliver_now : mail.deliver_later
  end

  def resend_confirmation_email
    generate_confirmation_token
    save!
    send_confirmation_email
  end

  def can_login?
    confirmed? && password_digest?
  end

end
