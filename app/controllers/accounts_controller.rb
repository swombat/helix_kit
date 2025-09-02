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
      audit(:convert_to_personal, @account, name: @account.name)
      redirect_to @account, notice: "Converted to personal account"
    when "team"
      old_name = @account.name
      @account.make_team!(params[:account][:name])
      audit(:convert_to_team, @account, from: old_name, to: @account.name)
      redirect_to @account, notice: "Converted to team account"
    else
      if @account.update!(account_params)
        audit_with_changes(:update_account_settings, @account) if @account.saved_changes.except(:updated_at).any?
        redirect_to @account, notice: "Account updated"
      end
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
