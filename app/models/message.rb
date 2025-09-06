class Message < ApplicationRecord

  include Broadcastable
  include ObfuscatesId

  acts_as_message

  belongs_to :chat, touch: true
  belongs_to :user, optional: true

  has_many_attached :files

  broadcasts_to :chat

  validates :role, inclusion: { in: %w[user assistant system] }
  validates :content, presence: true

end
