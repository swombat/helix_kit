module Services
  class Definition

    class UnknownProvider < KeyError; end

    attr_reader :key, :name, :management_scopes, :credential_strategy,
                 :api_origins, :documentation, :access_profiles,
                 :default_access_profile, :adapter_class, :connection_method,
                 :credential_fields, :runtime_notes

    def self.register(**attributes)
      definition = new(**attributes)
      registry[definition.key] = definition
      definition
    end

    def self.fetch(key)
      ensure_catalog_loaded
      registry.fetch(key.to_s) { raise UnknownProvider, "Unknown service provider: #{key}" }
    end

    def self.all
      ensure_catalog_loaded
      registry.values
    end

    def self.registry
      @registry ||= {}
    end

    def self.ensure_catalog_loaded
      Services::Catalog
    end

    def initialize(key:, name:, management_scopes:, credential_strategy:, api_origins:,
                   documentation:, access_profiles:, default_access_profile:, adapter_class:,
                   connection_method: "oauth2", credential_fields: [], runtime_notes: [])
      @key = key.to_s
      @name = name
      @management_scopes = management_scopes.map(&:to_s).freeze
      @credential_strategy = credential_strategy.to_s
      @api_origins = api_origins.freeze
      @documentation = documentation.freeze
      @access_profiles = access_profiles.to_h.transform_keys(&:to_s).transform_values { |v| Array(v).map(&:to_s).freeze }.freeze
      @default_access_profile = default_access_profile.to_s
      @adapter_class = adapter_class
      @connection_method = connection_method.to_s
      @credential_fields = credential_fields.map { |field| field.to_h.stringify_keys.freeze }.freeze
      @runtime_notes = Array(runtime_notes).map(&:to_s).freeze
    end

    def scopes_for(profile)
      access_profiles.fetch(profile.to_s)
    end

    def supports_management_scope?(scope)
      management_scopes.include?(scope.to_s)
    end

    def adapter
      adapter_class.constantize.new(self)
    end

    def as_json
      {
        key: key,
        name: name,
        management_scopes: management_scopes,
        connection_method: connection_method,
        credential_fields: credential_fields,
        credential_strategy: credential_strategy,
        access_profiles: access_profiles.map do |profile, scopes|
          {
            key: profile,
            name: profile.humanize,
            scopes: scopes,
            default: profile == default_access_profile
          }
        end
      }
    end

  end
end
