class RegistrationsController < ApplicationController

  allow_unauthenticated_access only: %i[ new create confirm_email set_password update_password check_email ]
  before_action :redirect_if_authenticated, only: [ :new ]
  before_action :load_pending_user, only: [ :set_password, :update_password ]

  def new
    render inertia: "registrations/signup"
  end

  def create
    user = User.register!(normalized_email)
    account_user = user.account_users.last

    if account_user.confirmed?
      redirect_to signup_path, inertia: {
        errors: { email_address: [ "This email is already registered. Please log in." ] }
      }
    else
      # Check if this is a resend (user already existed)
      is_resend = !user.was_new_record?

      notice = is_resend ?
        "Confirmation email resent. Please check your inbox." :
        "Please check your email to confirm your account."
      redirect_to check_email_path, notice: notice
    end
  rescue ActiveRecord::RecordInvalid => e
    redirect_to signup_path, inertia: { errors: e.record.errors.to_hash(true) }
  end

  def check_email
    render inertia: "registrations/check-email"
  end

  def confirm_email
    # Only use AccountUser confirmation - no fallback to User tokens
    account_user = AccountUser.confirm_by_token!(params[:token])
    user = account_user.user

    if user.password_digest?
      redirect_to login_path, notice: "Email confirmed! Please log in."
    else
      session[:pending_password_user_id] = user.id
      redirect_to set_password_path, notice: "Email confirmed! Please set your password."
    end
  rescue ActiveRecord::RecordNotFound, ActiveSupport::MessageVerifier::InvalidSignature
    redirect_to signup_path, alert: "Invalid or expired confirmation link. Please sign up again."
  end

  def set_password
    return redirect_to login_path, alert: "Invalid request. Please log in." if @user&.password_digest?

    render inertia: "registrations/set-password", props: { email: @user.email_address, user: @user.as_json }
  end

  def update_password
    if @user.update(password_params)
      session.delete(:pending_password_user_id)
      start_new_session_for @user
      redirect_to after_authentication_url, notice: "Account setup complete! Welcome!"
    else
      flash[:errors] = @user.errors.full_messages
      debug "Errors: #{flash[:errors].inspect}"
      redirect_to set_password_path
    end
  end

  private

  def normalized_email
    params[:email_address]&.strip&.downcase
  end

  def redirect_if_authenticated
    redirect_to root_path, alert: "You are already signed in." if authenticated?
  end

  def load_pending_user
    @user = User.find_by(id: session[:pending_password_user_id])
    redirect_to login_path, alert: "Invalid request. Please log in." unless @user
  end

  def password_params
    params.permit(:password, :password_confirmation, :first_name, :last_name)
  end

end
