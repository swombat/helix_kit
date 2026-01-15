class Current < ActiveSupport::CurrentAttributes

  attribute :session
  attribute :account
  attribute :api_user

  # User can come from either session (web) or api_user (API)
  def user
    api_user || session&.user
  end

end
