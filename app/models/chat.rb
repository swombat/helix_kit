class Chat < ApplicationRecord

  include Broadcastable
  include ObfuscatesId

  acts_as_chat

  belongs_to :account
  has_many :messages, dependent: :destroy

  broadcasts_to :account

  validates :model_id, presence: true

  after_create_commit -> { GenerateTitleJob.perform_later(self) }, unless: :title?

end
