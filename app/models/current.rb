class Current < ActiveSupport::CurrentAttributes

  attribute :session
  attribute :account

  delegate :user, to: :session, allow_nil: true

end
