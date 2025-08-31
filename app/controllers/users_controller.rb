class UsersController < ApplicationController

  def edit
    render inertia: "user/edit", props: {
      timezones: ActiveSupport::TimeZone.all.map { |tz| { value: tz.name, label: tz.to_s } }
    }
  end

  def update
    if Current.user.update(user_params)
      # Set theme cookie for faster initial page loads
      if params[:user][:preferences]&.key?(:theme)
        cookies[:theme] = {
          value: Current.user.theme,
          expires: 1.year.from_now,
          httponly: true,
          secure: Rails.env.production?
        }
      end
      flash[:success] = "Settings updated successfully"
    else
      flash[:errors] = Current.user.errors.full_messages
    end

    redirect_to edit_user_path
  end

  def edit_password
    render inertia: "user/edit_password"
  end

  def update_password
    if Current.user.authenticate(params[:current_password])
      if Current.user.update(password: params[:password], password_confirmation: params[:password_confirmation])
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

  private

  def user_params
    params.require(:user).permit(:first_name, :last_name, :timezone, preferences: [ :theme ])
  end

end
