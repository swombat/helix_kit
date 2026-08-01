class Notice < ApplicationRecord

  SCOPES = %w[system account].freeze
  TYPES = %w[model_changed site_renamed announcement].freeze

  belongs_to :account, optional: true
  belongs_to :created_by, class_name: "User", optional: true

  validates :scope, inclusion: { in: SCOPES }
  validates :notice_type, inclusion: { in: TYPES }
  validates :expires_at, presence: true
  validate :account_matches_scope

  scope :active, -> { where("expires_at > ?", Time.current) }

  def self.for_agent(agent)
    active.where(
      "scope = :system OR (scope = :account AND account_id = :account_id)",
      system: "system",
      account: "account",
      account_id: agent.account_id
    ).order(:created_at, :id)
  end

  private

  def account_matches_scope
    if scope == "system" && account_id.present?
      errors.add(:account, "must be absent for system notices")
    elsif scope == "account" && account_id.blank?
      errors.add(:account, "must be present for account notices")
    end
  end

end
