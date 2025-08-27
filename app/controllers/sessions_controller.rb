class SessionsController < ApplicationController
  allow_unauthenticated_access only: %i[ new create ]
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to new_session_url, alert: "Try again later." }

  def new
    if authenticated?
      redirect_to root_path, flash: { notice: "You are already signed in." }
    else
      render inertia: "sessions/login"
    end
  end

  def create
    if user = User.authenticate_by(session_params)
      start_new_session_for user
      redirect_to after_authentication_url, flash: { notice: "You have been signed in." }
    else
      flash[:alert] = "Invalid email or password."
      redirect_to login_path, inertia: { errors: { email_address: [ "Invalid email or password." ] } }
    end
  end

  def destroy
    terminate_session
    redirect_to root_path, flash: { notice: "You have been signed out." }
  end

  private

  def session_params
    params.permit(:email_address, :password)
  end
end
