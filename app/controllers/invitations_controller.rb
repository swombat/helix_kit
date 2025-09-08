# app/controllers/invitations_controller.rb
class InvitationsController < ApplicationController

  before_action :set_account
  before_action :authorize_management!

  def create
    send_invitation || redirect_with_invitation_errors
  end

  def resend
    resend_member_invitation || redirect_with_resend_error
  end

  private

  def send_invitation
    @invitation = create_invitation
    return false unless @invitation.save

    audit_invitation_sent
    redirect_with_invitation_success
    true
  end

  def create_invitation
    @account.invite_member(
      email: invitation_params[:email],
      role: invitation_params[:role],
      invited_by: Current.user
    )
  end

  def audit_invitation_sent
    audit(:invite_member, @invitation,
          invited_email: invitation_params[:email],
          role: invitation_params[:role])
  end

  def redirect_with_invitation_success
    redirect_to account_path(@account),
      notice: "Invitation sent to #{invitation_params[:email]}"
  end

  def redirect_with_invitation_errors
    redirect_to account_path(@account),
      alert: @invitation.errors.full_messages.to_sentence
  end

  def resend_member_invitation
    @member = find_account_member
    return false unless @member.resend_invitation!

    audit_invitation_resent
    redirect_with_resend_success
    true
  end

  def find_account_member
    @account.memberships.find(params[:id])
  end

  def audit_invitation_resent
    audit(:resend_invitation, @member,
          member_email: @member.user.email_address,
          role: @member.role)
  end

  def redirect_with_resend_success
    redirect_to account_path(@account), notice: "Invitation resent"
  end

  def redirect_with_resend_error
    redirect_to account_path(@account), alert: "Could not resend invitation"
  end

  def set_account
    @account = Current.user.accounts.find(params[:account_id])
  end

  def authorize_management!
    raise Account::NotAuthorized unless @account.manageable_by?(Current.user)
  rescue Account::NotAuthorized
    redirect_to account_path(@account),
      alert: "You don't have permission to manage members"
  end

  def invitation_params
    params.permit(:email, :role)
  end

end
