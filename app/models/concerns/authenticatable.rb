# app/models/concerns/authenticatable.rb
module Authenticatable

  extend ActiveSupport::Concern

  included do
    has_secure_password validations: false
    has_many :sessions, dependent: :destroy

    generates_token_for :password_reset, expires_in: 2.hours do
      password_salt&.last(10)
    end

    # Password validations
    validates :password, presence: true, length: { minimum: 8 },
                        if: -> { password.present? },
                        unless: :created_via_invitation?
    validates :password, confirmation: true, length: { in: 6..72 },
                        if: :password_digest_changed?
  end

  def send_password_reset
    update_columns(password_reset_token: nil, password_reset_sent_at: Time.current)
    PasswordsMailer.reset(self).deliver_later
  end

  def password_reset_token_for_url
    return unless password_reset_sent_at.present?

    generate_token_for(:password_reset)
  end

  def password_reset_expired?
    return true unless password_reset_sent_at
    password_reset_sent_at < 2.hours.ago
  end

  def clear_password_reset_token!
    update_columns(password_reset_token: nil, password_reset_sent_at: nil)
  end

  def can_login?
    confirmed? && password_digest?
  end

  # Check if user was created via invitation and hasn't set up their account yet
  # These users don't require a password until they confirm their account
  def created_via_invitation?
    memberships.any?(&:invitation?) && !confirmed?
  end

end
