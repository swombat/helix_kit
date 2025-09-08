class Admin::AccountsController < ApplicationController

  # Skip account scoping for admin controllers - admins can see all accounts
  skip_before_action :set_current_account

  before_action :require_site_admin

  def index
    @accounts = Account.includes(:owner, account_users: :user)
                       .order(created_at: :desc)

    # Admin can view any account, not just ones they belong to
    # So we bypass the AccountScoping concern's current_account method
    selected_account_id = params[:account_id]
    @selected_account = Account.find(selected_account_id) if selected_account_id.present?

    render inertia: "admin/accounts", props: {
      accounts: @accounts.as_json(
        include: [ :owner ],
        methods: [ :users_count, :members_count, :active ]
        ),
      selected_account: @selected_account ? @selected_account.as_json(
        include: [ :owner, :account_users ],
        methods: [ :users_count, :members_count, :active ]
      ) : nil
    }
  end

  private

  def require_site_admin
    redirect_to root_path unless Current.user&.is_site_admin?
  end

  # Override AccountScoping's current_account method for admin controllers
  # Admin controllers should not use account scoping
  def current_account
    nil
  end

end
