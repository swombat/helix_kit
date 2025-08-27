class ApplicationController < ActionController::Base
  include Authentication
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  inertia_share flash: -> { flash.to_hash }
  inertia_share do
    {
      user: Current.user
    } if authenticated?
  end

  wrap_parameters false # Disable default wrapping of parameters in JSON requests (Helpful with Inertia js)
end
