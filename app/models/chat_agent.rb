class ChatAgent < ApplicationRecord

  belongs_to :chat
  belongs_to :agent

  validates :agent_id, uniqueness: { scope: :chat_id }

end
