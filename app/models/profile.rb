class Profile < ApplicationRecord

  include JsonAttributes

  belongs_to :user

  # Avatar attachment - moved from User
  has_one_attached :avatar do |attachable|
    attachable.variant :thumb, resize_to_fill: [ 100, 100 ]
    attachable.variant :medium, resize_to_fill: [ 300, 300 ]
  end

  # Normalization
  normalizes :first_name, with: ->(name) { name&.strip }
  normalizes :last_name, with: ->(name) { name&.strip }

  # Validations
  validates :theme, inclusion: { in: %w[light dark system] }, allow_nil: true
  validates :timezone, inclusion: { in: ActiveSupport::TimeZone.all.map(&:name) }, allow_blank: true
  validates_presence_of :first_name, :last_name, if: -> { user&.confirmed? }

  # Avatar validations
  validates :avatar, content_type: [ "image/png", "image/jpeg", "image/gif", "image/webp" ],
                     size: { less_than: 5.megabytes }

  # Callbacks
  after_initialize :set_default_theme, if: :new_record?

  # JSON attributes to include theme preferences
  def preferences
    { "theme" => theme }.compact
  end

  def full_name
    "#{first_name} #{last_name}".strip.presence
  end

  def avatar_url
    return nil unless avatar.attached?

    if avatar.variable?
      Rails.application.routes.url_helpers.rails_representation_url(
        avatar.variant(resize_to_fill: [ 200, 200 ]),
        only_path: true
      )
    else
      Rails.application.routes.url_helpers.rails_blob_url(avatar, only_path: true)
    end
  end

  def initials
    return "?" unless full_name.present?
    full_name.split.map(&:first).first(2).join.upcase
  end

  private

  def set_default_theme
    self.theme ||= "system"
  end

end
