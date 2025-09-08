class ApplicationController < ActionController::Base

  include Pagy::Backend

  include Authentication
  include AccountScoping
  allow_browser versions: :modern

  rescue_from ActiveRecord::RecordNotFound, with: :record_not_found

  inertia_share flash: -> { flash.to_hash }
  inertia_share do
    if authenticated?
      {
        user: Current.user.as_json,
        account: current_account&.as_json,
        theme_preference: Current.user&.theme || cookies[:theme]
      }
    else
      {
        theme_preference: cookies[:theme]
      }
    end
  end

  wrap_parameters false # Disable default wrapping of parameters in JSON requests (Helpful with Inertia js)

  private

  def record_not_found
    if request.headers["X-Inertia"]
      # For Inertia requests, render a proper Inertia error response
      head :not_found
    else
      respond_to do |format|
        format.html { render file: "#{Rails.root}/public/404.html", status: :not_found, layout: false }
        format.json { render json: { error: "Record not found" }, status: :not_found }
        format.any { head :not_found }
      end
    end
  end

  def redirect_with_inertia_flash(type, message, path = nil)
    flash[type] = message
    redirect_to path || request.referer || root_path
  end

  # Centralized audit logging methods
  # Keep all AuditLog.create calls here so if audit logging principles change,
  # we only need to update in one place rather than hunting throughout the codebase

  def audit(action, auditable = nil, **data)
    return unless Current.user

    AuditLog.create!(
      user: Current.user,
      account: Current.account,
      action: action,
      auditable: auditable,
      data: data.presence,
      ip_address: request.remote_ip,
      user_agent: request.user_agent
    )
  end

  def audit_with_changes(action, record, **extra_data)
    return unless Current.user

    changes = record.saved_changes.except(:updated_at)
    data = extra_data.merge(changes)

    audit(action, record, **data)
  end

  # Use this method only when logging actions for a user outside of an authenticated session
  # (e.g., password reset requests where the user isn't logged in)
  def audit_as(user, action, auditable = nil, **data)
    AuditLog.create!(
      user: user,
      account: user.personal_account,
      action: action,
      auditable: auditable,
      data: data.presence,
      ip_address: request.remote_ip,
      user_agent: request.user_agent
    )
  end

end
