class UsersController < ApplicationController

  def edit
    render inertia: "user/edit", props: { timezones: timezone_options }
  end

  def update
    update_user_successfully || handle_update_failure
  end

  def edit_password
    render inertia: "user/edit_password"
  end

  def update_password
    return redirect_with_incorrect_password unless current_password_valid?

    update_password_successfully || redirect_with_password_errors
  end

  def destroy
    remove_user_avatar
    respond_with_avatar_removal_success
  end

  private

  def timezone_options
    ActiveSupport::TimeZone.all.map { |tz| { value: tz.name, label: tz.to_s } }
  end

  def update_user_successfully
    return false unless Current.user.update(user_params)

    audit_user_changes
    set_theme_cookie if theme_changed?
    respond_with_update_success
    true
  end

  def handle_update_failure
    respond_with_update_errors
  end

  def audit_user_changes
    audit_with_changes(determine_audit_action, Current.user)
  end

  def determine_audit_action
    changes = Current.user.saved_changes.except(:updated_at)
    return :change_theme if theme_preference_changed?(changes)
    return :update_timezone if changes.key?("timezone")
    return :set_avatar if user_params[:avatar].present?
    :update_profile
  end

  def theme_preference_changed?(changes)
    changes[:preferences]&.first&.key?("theme")
  end

  def respond_with_update_success
    inertia_request? ?
      redirect_with_inertia_flash(:success, "Settings updated successfully", edit_user_path) :
      render(json: { success: true }, status: :ok)
  end

  def respond_with_update_errors
    inertia_request? ?
      redirect_with_inertia_flash(:errors, Current.user.errors.full_messages, edit_user_path) :
      render(json: { errors: Current.user.errors.full_messages }, status: :unprocessable_entity)
  end

  def current_password_valid?
    Current.user.authenticate(params[:current_password])
  end

  def redirect_with_incorrect_password
    flash[:errors] = [ "Current password is incorrect" ]
    redirect_to edit_password_user_path
  end

  def update_password_successfully
    return false unless Current.user.update(password: params[:password], password_confirmation: params[:password_confirmation])

    audit(:change_password, Current.user)
    flash[:success] = "Password updated successfully"
    redirect_to edit_user_path
    true
  end

  def redirect_with_password_errors
    flash[:errors] = Current.user.errors.full_messages
    redirect_to edit_password_user_path
  end

  def remove_user_avatar
    Current.user.avatar.purge_later
    audit(:remove_avatar, Current.user)
  end

  def respond_with_avatar_removal_success
    inertia_request? ?
      redirect_with_inertia_flash(:success, "Avatar removed successfully", edit_user_path) :
      render(json: { success: true }, status: :ok)
  end

  def inertia_request?
    request.headers["X-Inertia"].present?
  end

  def user_params
    params.require(:user).permit(:first_name, :last_name, :timezone, :avatar, preferences: [ :theme ])
  end

  def theme_changed?
    params[:user][:preferences]&.key?(:theme)
  end

  def set_theme_cookie
    cookies[:theme] = {
      value: Current.user.theme,
      expires: 1.year.from_now,
      httponly: true,
      secure: Rails.env.production?
    }
  end

end
