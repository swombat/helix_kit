class Admin::AccountsController < ApplicationController

  before_action :require_site_admin

  def index
    @accounts = Account.includes(:owner, account_users: :user)
                       .order(created_at: :desc)

    selected_account_id = params[:account_id]
    @selected_account = @accounts.find { |a| a.id.to_s == selected_account_id } if selected_account_id

    render inertia: "admin/Accounts", props: {
      accounts: @accounts.map do |account|
        {
          id: account.id,
          name: account.name,
          account_type: account.account_type,
          created_at: account.created_at,
          owner: account.owner ? {
            id: account.owner.id,
            email: account.owner.email_address
          } : nil,
          users_count: account.account_users.size
        }
      end,
      selected_account: @selected_account ? {
        id: @selected_account.id,
        name: @selected_account.name,
        account_type: @selected_account.account_type,
        created_at: @selected_account.created_at,
        updated_at: @selected_account.updated_at,
        owner: @selected_account.owner ? {
          id: @selected_account.owner.id,
          email: @selected_account.owner.email_address,
          name: @selected_account.owner.full_name
        } : nil,
        users: @selected_account.account_users.map do |account_user|
          {
            id: account_user.user.id,
            email: account_user.user.email_address,
            name: account_user.user.full_name,
            role: account_user.role,
            created_at: account_user.created_at
          }
        end
      } : nil
    }
  end

  private

  def require_site_admin
    redirect_to root_path unless Current.user&.is_site_admin?
  end

end
