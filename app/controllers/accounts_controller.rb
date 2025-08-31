class AccountsController < ApplicationController

  before_action :set_account

  def show
    @members = @account.members_with_details if !@account.personal?

    render inertia: "accounts/show", props: {
      account: @account,
      can_be_personal: @account.can_be_personal?,
      members: @members ? @members.map { |m| m.as_json(current_user: Current.user) } : [],
      can_manage: Current.user.can_manage?(@account),
      current_user_id: Current.user.id
    }
  end

  def edit
    render inertia: "accounts/edit", props: { account: @account }
  end

  def update
    case params[:convert_to]
    when "personal"
      @account.make_personal!
      redirect_to @account, notice: "Converted to personal account"
    when "team"
      @account.make_team!(params[:account][:name])
      redirect_to @account, notice: "Converted to team account"
    else
      @account.update!(account_params)
      redirect_to @account, notice: "Account updated"
    end
  rescue ActiveRecord::RecordInvalid => e
    redirect_to @account, alert: e.message
  end

  private

  def set_account
    @account = Current.user.accounts.find(params[:id])
  end

  def account_params
    params.require(:account).permit(:name)
  end

end
