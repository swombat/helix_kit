class Admin::AuditLogsController < ApplicationController

  before_action :require_site_admin

  def index
    # Fat model handles filtering
    logs = AuditLog.filtered(processed_filters)
                   .includes(:user, :account)

    # Pagy handles pagination elegantly
    @pagy, @audit_logs = pagy(logs, items: params[:per_page] || 10)

    # Load selected log if requested
    @selected_log = AuditLog.find(params[:log_id]) if params[:log_id]

    render inertia: "admin/audit-logs", props: audit_logs_props
  end

  private

  def audit_logs_props
    {
      audit_logs: @audit_logs.map(&:as_json),
      selected_log: @selected_log&.as_json(
        include: [ :user, :account, :auditable ]
      ),
      pagination: @pagy ? {
        count: @pagy.count,
        page: @pagy.page,
        pages: @pagy.pages,
        last: @pagy.last,
        from: @pagy.from,
        to: @pagy.to,
        prev: @pagy.prev,
        next: @pagy.next,
        series: @pagy.series.collect(&:to_i),
        items: @pagy.vars[:items]
      } : {},
      filters: filter_options,
      current_filters: filter_params
    }
  end

  def filter_options
    {
      users: User.all.order(:email_address).map(&:as_json),
      accounts: Account.all.order(:name).map(&:as_json),
      actions: AuditLog.available_actions,
      types: AuditLog.available_types
    }
  end

  def processed_filters
    # Pre-process filters to convert comma-separated strings to arrays
    processed_filters = filter_params.dup
    if processed_filters[:user_id].is_a?(String)
      processed_filters[:user_id] = User.decode_ids_from_string(processed_filters[:user_id])
    end
    if processed_filters[:account_id].is_a?(String)
      processed_filters[:account_id] = Account.decode_ids_from_string(processed_filters[:account_id])
    end
    [ :audit_action, :auditable_type ].each do |key|
      if processed_filters[key].is_a?(String) && processed_filters[key].include?(",")
        processed_filters[key] = processed_filters[key].split(",").map(&:strip)
      end
    end
    processed_filters
  end

  def filter_params
    # NOTE: Exclude :action to avoid conflict with Rails controller action parameter
    params.permit(:user_id, :account_id, :audit_action, :auditable_type,
                  :date_from, :date_to, :page, :per_page, :log_id)
  end

  def require_site_admin
    redirect_to root_path unless Current.user&.is_site_admin?
  end

end
