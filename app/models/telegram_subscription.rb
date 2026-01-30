class TelegramSubscription < ApplicationRecord

  belongs_to :agent
  belongs_to :user

  scope :active, -> { where(blocked: false) }

  def mark_blocked!
    update!(blocked: true)
  end

end
