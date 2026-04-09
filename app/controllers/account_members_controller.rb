# app/controllers/account_members_controller.rb
class AccountMembersController < ApplicationController

  before_action :set_account
  before_action :require_account_manager!

  def destroy
    @member = @account.memberships.find(params[:id])
    if @member.owner? && @account.last_owner?
      redirect_to account_path(@account), alert: "Cannot remove the last owner"
      return
    end

    if @member.user_id == Current.user.id
      redirect_to account_path(@account), alert: "You can't remove yourself from this account"
      return
    end

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
    @account = find_current_user_account!(params[:account_id])
  end

end
