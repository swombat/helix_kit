class TweetLog < ApplicationRecord

  belongs_to :x_integration
  belongs_to :agent

  validates :tweet_id, presence: true, uniqueness: true
  validates :text, presence: true

  scope :recent, -> { order(created_at: :desc) }

end
