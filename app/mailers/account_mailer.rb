# app/mailers/account_mailer.rb
class AccountMailer < ApplicationMailer

  def confirmation(membership)
    @membership = membership
    @user = membership.user
    @account = membership.account
    @confirmation_url = email_confirmation_url(token: membership.confirmation_token)

    mail(
      to: @user.email_address,
      subject: "Confirm your email address"
    )
  end

  def team_invitation(membership)
    @membership = membership
    @user = membership.user
    @account = membership.account
    @inviter = membership.invited_by
    @confirmation_url = email_confirmation_url(token: membership.confirmation_token)

    mail(
      to: @user.email_address,
      subject: "You've been invited to join #{@account.name}"
    )
  end

end
