class SessionsController < ApplicationController

  allow_unauthenticated_access only: %i[ new create ]
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to new_session_url, alert: "Try again later." }

  def new
    if authenticated?
      redirect_to root_path, notice: "You are already signed in."
    else
      render inertia: "sessions/new"
    end
  end

  def create
    user = User.find_by(email_address: session_params[:email_address]&.strip&.downcase)

    if user && !user.can_login?
      alert = user.confirmed? ? "Please complete your account setup first." : "Please confirm your email address first."
      redirect_to signup_path, alert: alert
    elsif user = User.authenticate_by(session_params)
      start_new_session_for user
      audit(:login, user)
      redirect_to after_authentication_url, notice: "You have been signed in."
    else
      redirect_to login_path, alert: "Invalid email or password.",
        inertia: { errors: { email_address: [ "Invalid email or password." ] } }
    end
  end

  def destroy
    audit(:logout)
    terminate_session
    redirect_to root_path, notice: "You have been signed out."
  end

  private

  def session_params
    params.permit(:email_address, :password)
  end

end
