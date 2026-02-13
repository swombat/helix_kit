class ChatAgent < ApplicationRecord

  belongs_to :chat
  belongs_to :agent

  validates :agent_id, uniqueness: { scope: :chat_id }

  scope :closed_for_initiation, -> { where.not(closed_for_initiation_at: nil) }
  scope :open_for_initiation, -> { where(closed_for_initiation_at: nil) }

  def closed_for_initiation? = closed_for_initiation_at?

  def close_for_initiation!
    update!(closed_for_initiation_at: Time.current)
  end

  def reopen_for_initiation!
    update!(closed_for_initiation_at: nil)
  end

end
