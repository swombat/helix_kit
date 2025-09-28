class Setting < ApplicationRecord

  include Broadcastable

  has_one_attached :logo

  validates :site_name, presence: true, length: { maximum: 100 }
  validates :logo, content_type: [ :png, :jpg, :gif, :webp, :svg ],
                   size: { less_than: 5.megabytes },
                   if: -> { logo.attached? }

  broadcasts_to :all

  def self.instance
    first_or_create!(site_name: "HelixKit")
  end

end
