class TelegramMessage < ApplicationRecord

  include ObfuscatesId

  belongs_to :telegram_subscription, touch: true

  validates :role, inclusion: { in: %w[user assistant] }
  validates :text, presence: true
  validates :sent_at, presence: true

  scope :chronological, -> { order(:sent_at, :id) }

  def transcript_json
    {
      id: to_param,
      role: role,
      sender: sender_name,
      telegram_username: sender_username,
      text: text,
      timestamp: sent_at.iso8601
    }
  end

end
