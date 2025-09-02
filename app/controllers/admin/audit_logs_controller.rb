class Admin::AuditLogsController < ApplicationController

  before_action :require_site_admin

  def index
    # Fat model handles filtering
    logs = AuditLog.filtered(filter_params)
                   .includes(:user, :account)

    # Debug: Log the count
    Rails.logger.info "Audit logs count before pagination: #{logs.count}"
    Rails.logger.info "Filter params: #{filter_params.inspect}"

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
      users: User.all.order(:email_address).map { |u| { id: u.id, email_address: u.email_address } },
      accounts: Account.all.order(:name).map { |a| { id: a.id, name: a.name } },
      actions: AuditLog.available_actions,
      types: AuditLog.available_types
    }
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
