class ApplicationController < ActionController::Base

  include Authentication
  include AccountScoping
  include Auditable
  allow_browser versions: :modern

  inertia_share flash: -> { flash.to_hash }
  inertia_share do
    if authenticated?
      {
        user: Current.user.as_json,
        account: current_account&.as_json,
        theme_preference: Current.user&.theme || cookies[:theme]
      }
    else
      {
        theme_preference: cookies[:theme]
      }
    end
  end

  wrap_parameters false # Disable default wrapping of parameters in JSON requests (Helpful with Inertia js)

end
