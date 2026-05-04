# frozen_string_literal: true

class ApplicationGateway < ActionMCP::Gateway

  identified_by ApiKeyIdentifier

  def configure_session(session)
    session.session_data = { "user_id" => user.id }
  end

end
