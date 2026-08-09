require "test_helper"

class ServiceConnectionTest < ActiveSupport::TestCase

  test "legacy Oura references cannot duplicate credential material" do
    user = users(:user_1)
    integration = user.create_oura_integration!(
      access_token: "working-access-token",
      refresh_token: "working-refresh-token",
      token_expires_at: 2.days.from_now
    )

    connection = accounts(:personal_account).service_connections.new(
      connected_by_user: user,
      legacy_oura_integration: integration,
      provider: "oura",
      management_scope: "personal",
      credential_kind: "legacy_reference",
      credential_payload_hash: {
        "access_token" => "copied-access-token",
        "refresh_token" => "copied-refresh-token"
      }
    )

    assert_not connection.valid?
    assert_includes connection.errors[:credential_payload], "must remain empty for a legacy Oura reference"
  end

end
