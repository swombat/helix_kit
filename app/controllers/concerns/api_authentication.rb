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
    Current.api_key = @current_api_key
    Current.api_user = @current_api_key.user
    Current.api_agent = @current_api_key.agent
  end

  def current_api_user
    @current_api_key&.user
  end

  def current_api_account
    return Current.api_agent.account if Current.api_agent

    # An account-scoped key resolves to its account (the key's user is a
    # validated member of it). This is how a multi-account user reaches a
    # specific account via the API.
    return Current.api_key.account if Current.api_key&.account

    # Otherwise fall back to the user's first account (personal or team).
    current_api_user&.accounts&.first
  end

  def current_api_agent
    Current.api_agent
  end

end
