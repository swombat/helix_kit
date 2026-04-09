class UserMailer < ApplicationMailer

  def confirmation(user)
    @user = user
    membership = @user.memberships.unconfirmed.order(created_at: :desc).first
    @confirmation_url = email_confirmation_url(token: membership&.confirmation_token_for_url)

    mail(
      to: @user.email_address,
      subject: "Confirm your email address"
    )
  end

end
