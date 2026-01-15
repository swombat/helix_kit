module ApiAuthentication

  extend ActiveSupport::Concern

  included do
    before_action :authenticate_api_key!
  end

  private

  def authenticate_api_key!
    token = request.headers["Authorization"]&.delete_prefix("Bearer ")
    @current_api_key = ApiKey.authenticate(token)

    unless @current_api_key
      render json: { error: "Invalid or missing API key" }, status: :unauthorized
      return
    end

    @current_api_key.touch_usage!(request.remote_ip)
    Current.api_user = @current_api_key.user
  end

  def current_api_user
    @current_api_key&.user
  end

  def current_api_account
    # Use the user's first account (personal or team)
    # In future, could scope keys to specific accounts
    current_api_user&.accounts&.first
  end

end
