class PagesController < ApplicationController

  allow_unauthenticated_access

  def home
    render inertia: "Home"
  end

end
