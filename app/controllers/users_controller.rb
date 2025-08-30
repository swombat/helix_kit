class UsersController < ApplicationController

  def edit
    render inertia: "user/Settings", props: {
      timezones: ActiveSupport::TimeZone.all.map { |tz| { value: tz.name, label: tz.to_s } }
    }
  end

  def update
    if Current.user.update(user_params)
      flash[:success] = "Settings updated successfully"
    else
      flash[:errors] = Current.user.errors.full_messages
    end

    # flash[:errors] = [ "test error", "test error 2" ]
    redirect_to edit_user_path
  end

  private

  def user_params
    params.require(:user).permit(:first_name, :last_name, :timezone)
  end

end
