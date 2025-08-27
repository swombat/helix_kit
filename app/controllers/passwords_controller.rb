class PasswordsController < ApplicationController
  allow_unauthenticated_access
  before_action :set_user_by_token, only: %i[ edit update ]

  def new
    render inertia: "passwords/new"
  end

  def create
    if user = User.find_by(email_address: params[:email_address])
      PasswordsMailer.reset(user).deliver_later
    end

    redirect_to login_path, notice: "Password reset instructions sent (if user with that email address exists)."
  end

  def edit
    render inertia: "passwords/edit", props: { token: params[:token] }
  end

  def update
    if @user.update(params.permit(:password, :password_confirmation))
      redirect_to login_path, notice: "Password has been reset."
    else
      redirect_to edit_password_path(params[:token]), inertia: { errors: @user.errors }
    end
  end

  private
    def set_user_by_token
      @user = User.find_by_password_reset_token!(params[:token])
    rescue ActiveSupport::MessageVerifier::InvalidSignature
      redirect_to new_password_path, alert: "Password reset link is invalid or has expired."
    end
end
