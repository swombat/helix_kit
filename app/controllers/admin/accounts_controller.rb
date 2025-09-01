class Admin::AccountsController < ApplicationController

  before_action :require_site_admin

  def index
    @accounts = Account.includes(:owner, account_users: :user)
                       .order(created_at: :desc)

    selected_account_id = params[:account_id]
    @selected_account = Account.find(selected_account_id) if selected_account_id

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

end
