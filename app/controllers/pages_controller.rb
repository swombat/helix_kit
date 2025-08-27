class PagesController < ApplicationController
  allow_unauthenticated_access

  def home
    render inertia: "Home"
  end

  def create_flash
    flash[:notice] = "This is a notice"
    flash[:alert] = "This is an alert"
    flash[:error] = "This is an error"
    redirect_to root_path
  end
end
