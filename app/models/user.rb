class User < ApplicationRecord

  has_secure_password
  has_many :sessions, dependent: :destroy

  normalizes :email_address, with: ->(e) { e.strip.downcase }
  validates :email_address, presence: true, uniqueness: { case_sensitive: false }, format: {
    with: /\A[\w+\-.]+@[a-z\d\-]+(\.[a-z]+)*\.[a-z]+\z/i,
    message: "must be a valid email address"
  }
  validates :password, confirmation: true, length: {
    minimum: 6,
    maximum: 72,
    message: "must be between 6 and 72 characters"
  }

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

  def generate_password_reset_token
    generate_token_for(:password_reset)
  end

end
