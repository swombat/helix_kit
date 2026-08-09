module Services
  class OuraAdapter

    attr_reader :definition

    def initialize(definition)
      @definition = definition
    end

    def authorization_url(*)
      raise NotImplementedError, "Connect Oura through the existing Oura consent flow, then adopt it into an account"
    end

    def exchange_code(*)
      raise NotImplementedError, "Oura generic OAuth is deferred while legacy credentials remain authoritative"
    end

    def revoke(_connection)
      # Compatibility connections must never revoke or clear the legacy Oura
      # credential merely because account-scoped resident access is removed.
      true
    end

  end
end
