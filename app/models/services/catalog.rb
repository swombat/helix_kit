module Services
  module Catalog

    DROPBOX_READ = %w[
      account_info.read
      files.metadata.read
      files.content.read
    ].freeze
    DROPBOX_WRITE = (DROPBOX_READ + %w[
      files.metadata.write
      files.content.write
    ]).freeze
    DROPBOX_SHARING = (DROPBOX_WRITE + %w[
      sharing.read
      sharing.write
    ]).freeze

    Services::Definition.register(
      key: "dropbox",
      name: "Dropbox",
      management_scopes: %w[personal account_managed],
      credential_strategy: "self_refreshing",
      api_origins: %w[https://api.dropboxapi.com https://content.dropboxapi.com],
      documentation: [ "https://www.dropbox.com/developers/documentation/http/documentation" ],
      access_profiles: {
        read_only: DROPBOX_READ,
        read_write: DROPBOX_WRITE,
        full_sharing: DROPBOX_SHARING
      },
      default_access_profile: "read_only",
      adapter_class: "Services::DropboxAdapter"
    )

    Services::Definition.register(
      key: "oura",
      name: "Oura Ring",
      management_scopes: %w[personal],
      credential_strategy: "refresh_broker",
      api_origins: %w[https://api.ouraring.com],
      documentation: [ "https://cloud.ouraring.com/v2/docs" ],
      access_profiles: {
        health_read: OuraApi::SCOPES
      },
      default_access_profile: "health_read",
      adapter_class: "Services::OuraAdapter"
    )

  end
end
