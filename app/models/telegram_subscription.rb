class TelegramSubscription < ApplicationRecord

  include ObfuscatesId

  belongs_to :agent
  belongs_to :user
  has_many :telegram_messages, dependent: :destroy

  scope :active, -> { where(blocked: false) }

  def subscriber_name
    user.full_name.presence || user.email_address
  end

  def mark_blocked!
    update!(blocked: true)
  end

end
