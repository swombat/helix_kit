module SyncAuthorizable

  extend ActiveSupport::Concern

  module ClassMethods

    def accessible_by(user)
      return none unless user

      # If model has account association, use account-based access
      if reflect_on_association(:account)
        return all if user.site_admin
        joins(:account).where(account: user.accounts)
      else
        # No account means admin-only
        user.site_admin ? all : none
      end
    end

  end

end
