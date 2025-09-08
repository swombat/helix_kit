class PasswordsController < ApplicationController

  allow_unauthenticated_access
  before_action :set_user_by_token, only: %i[ edit update ]

  def new
    render inertia: "passwords/new"
  end

  def create
    initiate_password_reset_if_user_exists
    redirect_with_reset_confirmation
  end

  def edit
    render inertia: "passwords/edit", props: { token: params[:token] }
  end

  def update
    reset_password || redirect_with_errors
  end

  private

  def set_user_by_token
    @user = User.find_by(password_reset_token: params[:token])
    redirect_with_invalid_token unless valid_reset_token?
  end

  def initiate_password_reset_if_user_exists
    return unless user = find_user_by_email

    audit_as(user, :password_reset_requested, user, requested_at: Time.current)
    user.send_password_reset
  end

  def find_user_by_email
    User.find_by(email_address: params[:email_address])
  end

  def redirect_with_reset_confirmation
    redirect_to login_path, notice: "Password reset instructions sent (if user with that email address exists)."
  end

  def reset_password
    return false unless @user.update(password_params)

    audit_as(@user, :password_reset_completed, @user)
    @user.clear_password_reset_token!
    redirect_to login_path, notice: "Password has been reset."
    true
  end

  def redirect_with_errors
    redirect_to edit_password_path(params[:token]), inertia: { errors: @user.errors }
  end

  def valid_reset_token?
    @user.present? && !@user.password_reset_expired?
  end

  def redirect_with_invalid_token
    redirect_to new_password_path, alert: "Password reset link is invalid or has expired."
  end

  def password_params
    params.permit(:password, :password_confirmation)
  end

end
