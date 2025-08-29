# app/mailers/account_mailer.rb
class AccountMailer < ApplicationMailer

  def confirmation(account_user)
    @account_user = account_user
    @user = account_user.user
    @account = account_user.account
    @confirmation_url = email_confirmation_url(token: account_user.confirmation_token)

    mail(
      to: @user.email_address,
      subject: "Confirm your email address"
    )
  end

  def team_invitation(account_user)
    @account_user = account_user
    @user = account_user.user
    @account = account_user.account
    @inviter = account_user.invited_by
    @confirmation_url = email_confirmation_url(token: account_user.confirmation_token)

    mail(
      to: @user.email_address,
      subject: "You've been invited to join #{@account.name}"
    )
  end

end
