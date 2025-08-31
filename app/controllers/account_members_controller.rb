# app/controllers/account_members_controller.rb
class AccountMembersController < ApplicationController

  before_action :set_account

  def destroy
    @member = @account.account_users.find(params[:id])

    if @member.destroy
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
