module InertiaResponses

  extend ActiveSupport::Concern

  private

  def respond_to_inertia_or_json(success_message: nil, error_message: nil, redirect_path: nil)
    if success_message
      respond_to_success(success_message, redirect_path)
    else
      respond_to_error(error_message)
    end
  end

  def respond_to_success(message, redirect_path = nil)
    if inertia_request?
      flash[:success] = message
      redirect_to redirect_path || request.referer || root_path
    else
      render json: { success: true }, status: :ok
    end
  end

  def respond_to_error(errors, redirect_path = nil)
    errors = [ errors ] unless errors.is_a?(Array)

    if inertia_request?
      flash[:errors] = errors
      redirect_to redirect_path || request.referer || root_path
    else
      render json: { errors: errors }, status: :unprocessable_entity
    end
  end

  def inertia_request?
    request.headers["X-Inertia"].present?
  end

end
