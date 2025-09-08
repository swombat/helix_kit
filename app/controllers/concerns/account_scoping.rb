module AccountScoping

  extend ActiveSupport::Concern

  included do
    helper_method :current_account, :current_membership
    before_action :set_current_account
  end

  private

  def current_account
    @current_account ||= if params[:account_id]
      Current.user&.accounts&.find(params[:account_id])
    else
      Current.user&.default_account
    end
  end

  def current_membership
    @current_membership ||= if current_account && Current.user
      Current.user.memberships.confirmed.find_by(account: current_account)
    end
  end

  def require_account
    redirect_to account_required_path unless current_account
  end

  def set_current_account
    Current.account = current_account
  end

  def authorize_account_resource(resource)
    return unless resource.respond_to?(:account) # Resources without account are not scoped to an account

    unless resource && resource.account.accessible_by?(Current.user)
      redirect_to unauthorized_path, alert: "You don't have access to this resource"
    end
  end

end
