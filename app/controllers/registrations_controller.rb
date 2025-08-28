class RegistrationsController < ApplicationController

  allow_unauthenticated_access only: %i[ new create ]

  def new
    if authenticated?
      redirect_to root_path, flash: { alert: "You are already signed in." }
    else
      render inertia: "registrations/signup"
    end
  end

  def create
    user = User.new(user_params)
    if user.save
      start_new_session_for user
      redirect_to after_authentication_url, flash: { notice: "Successfully signed up!" }
    else
      p user.errors.to_hash(true)
      redirect_to signup_path, inertia: {
        errors: user.errors.to_hash(true) # Convert ActiveModel::Errors to a hash for Inertia
      }
    end
  end

  private

  def user_params
    params.permit(
      :email_address,
      :password,
      :password_confirmation
    )
  end

end
