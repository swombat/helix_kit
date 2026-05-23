class Admin::AccountMembershipsController < ApplicationController

  skip_before_action :set_current_account

  before_action :require_site_admin
  before_action :set_account
  before_action :set_membership, only: :destroy

  def create
    user = User.find_by(email_address: membership_params[:email].to_s.strip.downcase)

    unless user
      redirect_to admin_accounts_path(account_id: @account), alert: "No user found with that email address"
      return
    end

    if @account.memberships.exists?(user: user)
      redirect_to admin_accounts_path(account_id: @account), alert: "User already belongs to this account"
      return
    end

    membership = @account.memberships.build(user: user, role: membership_params[:role])
    membership.skip_confirmation = true

    if membership.save
      audit(:admin_add_account_member, @account,
        account_id: @account.id,
        membership_id: membership.id,
        added_user_id: user.id,
        added_email: user.email_address,
        role: membership.role)
      redirect_to admin_accounts_path(account_id: @account), notice: "Member added"
    else
      redirect_to admin_accounts_path(account_id: @account), alert: membership.errors.full_messages.to_sentence
    end
  end

  def destroy
    if @membership.destroy
      audit(:admin_remove_account_member, @account,
        account_id: @account.id,
        membership_id: @membership.id,
        removed_user_id: @membership.user_id,
        removed_email: @membership.user.email_address)
      redirect_to admin_accounts_path(account_id: @account), notice: "Member removed"
    else
      redirect_to admin_accounts_path(account_id: @account), alert: @membership.errors.full_messages.to_sentence
    end
  end

  private

  def set_account
    @account = Account.find(params[:account_id])
  end

  def set_membership
    @membership = @account.memberships.includes(:user).find(params[:id])
  end

  def membership_params
    params.fetch(:membership, {}).permit(:email, :role)
  end

  def require_site_admin
    redirect_to root_path unless Current.user&.is_site_admin?
  end

  def current_account
    nil
  end

end
