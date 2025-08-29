class RegistrationsController < ApplicationController

  allow_unauthenticated_access only: %i[ new create confirm_email set_password update_password check_email ]
  before_action :redirect_if_authenticated, only: [ :new ]
  before_action :load_pending_user, only: [ :set_password, :update_password ]

  def new
    render inertia: "registrations/signup"
  end

  def create
    user = User.find_or_initialize_by(email_address: normalized_email)

    return redirect_with_error("This email is already registered. Please log in.") if user.confirmed?

    notice = if user.persisted?
      user.resend_confirmation_email
      "Confirmation email resent. Please check your inbox."
    else
      # Validate email format before saving
      user.valid?
      return redirect_to(signup_path, inertia: { errors: user.errors.to_hash(true) }) if user.errors[:email_address].any?

      user.save(validate: false) # Skip password validation
      user.send_confirmation_email
      "Please check your email to confirm your account."
    end

    redirect_to check_email_path, notice: notice
  end

  def check_email
    render inertia: "registrations/check-email"
  end

  def confirm_email
    user = User.find_by_confirmation_token!(params[:token])

    return redirect_to login_path, notice: "Email already confirmed. Please log in." if user.confirmed?

    user.confirm!
    session[:pending_password_user_id] = user.id
    redirect_to set_password_path, notice: "Email confirmed! Please set your password."
  rescue ActiveSupport::MessageVerifier::InvalidSignature
    redirect_to signup_path, alert: "Invalid or expired confirmation link. Please sign up again."
  end

  def set_password
    return redirect_to login_path, alert: "Invalid request. Please log in." if @user&.password_digest?

    render inertia: "registrations/set-password", props: { email: @user.email_address }
  end

  def update_password
    if @user.update(password_params)
      session.delete(:pending_password_user_id)
      start_new_session_for @user
      redirect_to after_authentication_url, notice: "Account setup complete! Welcome!"
    else
      redirect_to set_password_path, inertia: { errors: @user.errors.to_hash(true) }
    end
  end

  private

  def normalized_email
    params[:email_address]&.strip&.downcase
  end

  def redirect_with_error(message)
    redirect_to signup_path, inertia: {
      errors: { email_address: [ message ] }
    }
  end

  def redirect_if_authenticated
    redirect_to root_path, alert: "You are already signed in." if authenticated?
  end

  def load_pending_user
    @user = User.find_by(id: session[:pending_password_user_id])
    redirect_to login_path, alert: "Invalid request. Please log in." unless @user
  end

  def password_params
    params.permit(:password, :password_confirmation)
  end

end
