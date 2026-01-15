class ApiKeyRequest < ApplicationRecord

  EXPIRY_DURATION = 10.minutes

  belongs_to :api_key, optional: true

  validates :request_token, presence: true, uniqueness: true
  validates :client_name, presence: true, length: { maximum: 100 }
  validates :status, presence: true, inclusion: { in: %w[pending approved denied expired] }
  validates :expires_at, presence: true

  scope :pending, -> { where(status: "pending") }

  def self.create_request(client_name:)
    create!(
      request_token: SecureRandom.urlsafe_base64(32),
      client_name: client_name,
      status: "pending",
      expires_at: EXPIRY_DURATION.from_now
    )
  end

  def approve!(user:, key_name:)
    transaction do
      api_key = ApiKey.generate_for(user, name: key_name)
      raw_token = api_key.raw_token

      # Store encrypted raw token temporarily for CLI retrieval
      update!(
        status: "approved",
        api_key: api_key,
        approved_token_encrypted: encrypt_token(raw_token)
      )

      api_key
    end
  end

  def retrieve_approved_token!
    return nil unless approved? && approved_token_encrypted.present?

    raw_token = decrypt_token(approved_token_encrypted)
    # Clear after retrieval for security
    update_column(:approved_token_encrypted, nil)
    raw_token
  end

  def deny!
    update!(status: "denied")
  end

  def status_for_client
    return "expired" if status == "pending" && expires_at < Time.current
    status
  end

  def expired?
    status_for_client == "expired"
  end

  def pending?
    status_for_client == "pending"
  end

  def approved?
    status == "approved"
  end

  def denied?
    status == "denied"
  end

  private

  def encrypt_token(token)
    Rails.application.message_verifier(:api_key_request).generate(token, expires_in: EXPIRY_DURATION)
  end

  def decrypt_token(encrypted)
    Rails.application.message_verifier(:api_key_request).verified(encrypted)
  rescue ActiveSupport::MessageVerifier::InvalidSignature
    nil
  end

end
