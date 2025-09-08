module Confirmable

  extend ActiveSupport::Concern

  included do
    before_create :generate_confirmation_token, if: :needs_confirmation?

    scope :confirmed, -> { where.not(confirmed_at: nil) }
    scope :unconfirmed, -> { where(confirmed_at: nil) }

    generates_token_for :email_confirmation, expires_in: 24.hours do
      confirmable_attributes_for_token
    end
  end

  def confirmed?
    confirmed_at.present?
  end

  def confirm!
    return true if confirmed?

    update!(
      confirmed_at: Time.current,
      confirmation_token: nil
    )
  end

  def generate_confirmation_token
    self.confirmation_token = generate_token_for(:email_confirmation)
    self.confirmation_sent_at = Time.current
  end

  def resend_confirmation!
    generate_confirmation_token
    save!
    send_confirmation_email
  end

  private

  def needs_confirmation?
    confirmation_token.blank? && confirmed_at.blank?
  end

  def confirmable_attributes_for_token
    respond_to?(:email_address) ? email_address : id.to_s
  end

end
