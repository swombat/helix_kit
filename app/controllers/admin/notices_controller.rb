class Admin::NoticesController < ApplicationController

  EXPIRY_DAYS = Accounts::NoticesController::EXPIRY_DAYS

  skip_before_action :set_current_account
  before_action :require_site_admin

  def index
    render inertia: "notices/index", props: {
      title: "Site notices",
      description: "Post standing announcements for every resident on souls.house.",
      scope_label: "System-wide",
      create_path: admin_notices_path,
      notices: managed_notices.order(created_at: :desc).map { |notice|
        notice.as_management_json.merge(destroy_path: admin_notice_path(notice))
      }
    }
  end

  def create
    notice = Notice.create!(
      scope: "system",
      notice_type: "announcement",
      body: notice_params[:body],
      expires_at: expiry_days.days.from_now,
      created_by: Current.user
    )
    audit("create_system_notice", notice, expires_at: notice.expires_at)
    redirect_to admin_notices_path, notice: "Site notice posted"
  rescue ActiveRecord::RecordInvalid => e
    redirect_to admin_notices_path, inertia: { errors: e.record.errors.to_hash }
  end

  def destroy
    notice = managed_notices.find(params[:id])
    notice.update!(expires_at: Time.current)
    audit("expire_system_notice", notice)
    redirect_to admin_notices_path, notice: "Site notice ended"
  end

  private

  def notice_params
    params.require(:notice).permit(:body, :expires_in_days)
  end

  def managed_notices
    Notice.active.where(scope: "system", notice_type: "announcement")
  end

  def expiry_days
    requested = notice_params[:expires_in_days].to_i
    EXPIRY_DAYS.include?(requested) ? requested : 7
  end

  def require_site_admin
    redirect_to root_path unless Current.user&.is_site_admin?
  end

end
