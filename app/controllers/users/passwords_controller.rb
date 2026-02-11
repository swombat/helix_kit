class Users::PasswordsController < ApplicationController

  def edit
    render inertia: "user/edit_password"
  end

  def update
    return redirect_with_incorrect_password unless current_password_valid?

    update_password_successfully || redirect_with_password_errors
  end

  private

  def current_password_valid?
    Current.user.authenticate(params[:current_password])
  end

  def redirect_with_incorrect_password
    flash[:errors] = [ "Current password is incorrect" ]
    redirect_to edit_user_password_path
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
    redirect_to edit_user_password_path
  end

end
