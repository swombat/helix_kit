class UserMailer < ApplicationMailer

  def confirmation(user)
    @user = user
    @confirmation_url = email_confirmation_url(token: @user.confirmation_token)

    mail(
      to: @user.email_address,
      subject: "Confirm your email address"
    )
  end

end
