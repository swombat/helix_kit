class AuditLog < ApplicationRecord

  include ObfuscatesId
  include SyncAuthorizable
  include Broadcastable

  belongs_to :user, optional: true
  belongs_to :account, optional: true
  belongs_to :auditable, polymorphic: true, optional: true

  validates :action, presence: true

  # Broadcast to admin collection for real-time updates
  broadcasts_to :all

  # Scopes for filtering (composable and chainable)
  scope :recent, -> { order(created_at: :desc) }
  scope :by_user, ->(user_id) { where(user_id: user_id) if user_id.present? }
  scope :by_account, ->(account_id) { where(account_id: account_id) if account_id.present? }
  scope :by_action, ->(action) { where(action: action) if action.present? }
  scope :by_type, ->(type) { where(auditable_type: type) if type.present? }
  scope :date_from, ->(date) { where("created_at >= ?", Date.parse(date.to_s)) if date.present? }
  scope :date_to, ->(date) { where("created_at <= ?", Date.parse(date.to_s).end_of_day) if date.present? }

  # Single method for filtered results (fat model)
  def self.filtered(filters = {})
    result = all

    # Pre-process filters to convert comma-separated strings to arrays
    processed_filters = filters.dup
    [ :user_id, :account_id, :audit_action, :auditable_type ].each do |key|
      if processed_filters[key].is_a?(String) && processed_filters[key].include?(",")
        processed_filters[key] = processed_filters[key].split(",").map(&:strip)
      end
    end

    # Apply filters only if they have values
    result = result.by_user(processed_filters[:user_id]) if processed_filters[:user_id].present?
    result = result.by_account(processed_filters[:account_id]) if processed_filters[:account_id].present?
    result = result.by_action(processed_filters[:audit_action]) if processed_filters[:audit_action].present?
    result = result.by_type(processed_filters[:auditable_type]) if processed_filters[:auditable_type].present?
    result = result.date_from(processed_filters[:date_from]) if processed_filters[:date_from].present?
    result = result.date_to(processed_filters[:date_to]) if processed_filters[:date_to].present?

    result.recent
  end

  # Class methods for filter options
  def self.available_actions
    distinct.pluck(:action).compact.sort
  end

  def self.available_types
    distinct.pluck(:auditable_type).compact.sort
  end

  # Instance methods for display
  def display_action
    action.to_s.humanize
  end

  def summary
    parts = [ display_action ]
    parts << auditable_type.to_s.humanize if auditable_type
    parts << "##{auditable_id}" if auditable_id
    parts.join(" ")
  end

  def actor_name
    user&.email_address || "System"
  end

  def target_name
    account&.name || "-"
  end

  # For JSON serialization
  def as_json(options = {})
    super(options).merge(
      display_action: display_action,
      summary: summary,
      actor_name: actor_name,
      target_name: target_name
    )
  end

end
