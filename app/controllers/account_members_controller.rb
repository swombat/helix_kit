# app/controllers/account_members_controller.rb
class AccountMembersController < ApplicationController

  before_action :set_account

  def destroy
    @member = @account.account_users.find(params[:id])
    member_email = @member.user.email_address
    member_role = @member.role

    if @member.destroy
      audit(:remove_member, nil,
            removed_email: member_email,
            removed_role: member_role)
      redirect_to account_path(@account),
        notice: "Member removed successfully"
    else
      redirect_to account_path(@account),
        alert: @member.errors.full_messages.to_sentence
    end
  end

  private

  def set_account
    # Association-based authorization - The Rails Way!
    @account = Current.user.accounts.find(params[:account_id])
  end

end
