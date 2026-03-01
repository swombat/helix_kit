class XIntegration < ApplicationRecord

  include XApi

  belongs_to :account
  has_many :tweet_logs, dependent: :destroy

  validates :account_id, uniqueness: true

  scope :enabled, -> { where(enabled: true) }

end
