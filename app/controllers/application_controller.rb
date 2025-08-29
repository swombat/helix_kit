class ApplicationController < ActionController::Base

  include Authentication
  include AccountScoping
  allow_browser versions: :modern

  inertia_share flash: -> { flash.to_hash }
  inertia_share do
    if authenticated?
      {
        user: Current.user.slice(:id, :email_address),
        account: current_account&.slice(:id, :name, :account_type)
      }
    end
  end

  wrap_parameters false # Disable default wrapping of parameters in JSON requests (Helpful with Inertia js)

end
