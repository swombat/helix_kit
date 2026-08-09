require "test_helper"

class DropboxServiceIntegrationTest < ActiveSupport::TestCase

  test "Dropbox adapter can identify the configured test account" do
    token = if ENV["RECORD_CASSETTES"] == "1"
      Rails.application.credentials.dig(:dropbox, :secret)
    else
      "dropbox-test-token"
    end

    assert token.present?, "Configure dropbox.secret before recording this cassette"

    identity = VCR.use_cassette("services/dropbox/get_current_account") do
      Services::Definition.fetch("dropbox").adapter.send(:fetch_identity, token)
    end

    assert_equal "dbid:test-account", identity.fetch("account_id")
    assert_equal "dropbox-test@example.test", identity.fetch("email")
    assert_equal "Dropbox Test", identity.dig("name", "display_name")
  end

end
