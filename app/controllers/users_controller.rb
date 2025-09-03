class UsersController < ApplicationController

  include InertiaResponses

  def edit
    render inertia: "user/edit", props: {
      timezones: ActiveSupport::TimeZone.all.map { |tz| { value: tz.name, label: tz.to_s } }
    }
  end

  def update
    if Current.user.update(user_params)
      changes = Current.user.saved_changes.except(:updated_at)
      Current.user.audit_profile_changes!(changes)

      set_theme_cookie if theme_changed?
      respond_to_success("Settings updated successfully", edit_user_path)
    else
      respond_to_error(Current.user.errors.full_messages, edit_user_path)
    end
  end

  def edit_password
    render inertia: "user/edit_password"
  end

  def update_password
    if Current.user.authenticate(params[:current_password])
      if Current.user.update(password: params[:password], password_confirmation: params[:password_confirmation])
        audit(:change_password, Current.user)  # Never log passwords!
        flash[:success] = "Password updated successfully"
        redirect_to edit_user_path
      else
        flash[:errors] = Current.user.errors.full_messages
        redirect_to edit_password_user_path
      end
    else
      flash[:errors] = [ "Current password is incorrect" ]
      redirect_to edit_password_user_path
    end
  end

  def destroy
    Current.user.avatar.purge_later
    audit(:remove_avatar, Current.user)
    respond_to_success("Avatar removed successfully", edit_user_path)
  end

  private

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
