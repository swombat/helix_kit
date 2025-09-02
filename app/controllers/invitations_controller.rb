# app/controllers/invitations_controller.rb
class InvitationsController < ApplicationController

  before_action :set_account

  def create
    @invitation = @account.invite_member(
      email: invitation_params[:email],
      role: invitation_params[:role],
      invited_by: Current.user
    )

    if @invitation.save
      # Clean and simple - account context is automatic
      audit(:invite_member, @invitation,
            invited_email: invitation_params[:email],
            role: invitation_params[:role])
      redirect_to account_path(@account),
        notice: "Invitation sent to #{invitation_params[:email]}"
    else
      redirect_to account_path(@account),
        alert: @invitation.errors.full_messages.to_sentence
    end
  end

  def resend
    @member = @account.account_users.find(params[:id])

    if @member.resend_invitation!
      audit(:resend_invitation, @member,
            member_email: @member.user.email_address,
            role: @member.role)
      redirect_to account_path(@account),
        notice: "Invitation resent"
    else
      redirect_to account_path(@account),
        alert: "Could not resend invitation"
    end
  end

  private

  def set_account
    # Use association-based authorization
    @account = Current.user.accounts.find(params[:account_id])

    # Only check management permission in this controller
    unless Current.user.can_manage?(@account)
      redirect_to account_path(@account),
        alert: "You don't have permission to manage members"
    end
  end

  def invitation_params
    params.permit(:email, :role)
  end

end
