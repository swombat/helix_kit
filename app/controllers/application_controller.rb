class ApplicationController < ActionController::Base

  include Pagy::Backend

  include Authentication
  include AccountScoping
  include Auditable
  allow_browser versions: :modern

  rescue_from ActiveRecord::RecordNotFound, with: :record_not_found

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

  private

  def record_not_found
    if request.headers["X-Inertia"]
      # For Inertia requests, render a proper Inertia error response
      head :not_found
    else
      respond_to do |format|
        format.html { render file: "#{Rails.root}/public/404.html", status: :not_found, layout: false }
        format.json { render json: { error: "Record not found" }, status: :not_found }
        format.any { head :not_found }
      end
    end
  end

end
