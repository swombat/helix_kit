require "test_helper"

class ServiceConnectionTest < ActiveSupport::TestCase

  test "refresh broker exposes only the current access token and broker endpoint" do
    user = users(:user_1)
    connection = accounts(:personal_account).service_connections.create!(
      connected_by_user: user,
      provider: "oura",
      external_subject_id: "oura-user-1",
      management_scope: "personal",
      credential_kind: "oauth2",
      credential_payload_hash: {
        "access_token" => "current-access-token",
        "refresh_token" => "private-refresh-token",
        "expires_at" => 2.days.from_now.utc.iso8601
      },
      credential_metadata: {
        "credential_strategy" => "refresh_broker",
        "granted_scopes" => OuraApi::SCOPES
      }
    )

    credentials = connection.runtime_credentials(agent: agents(:research_assistant))

    assert_equal "current-access-token", credentials["access_token"]
    assert_not credentials.key?("refresh_token")
    assert_includes credentials["access_token_endpoint"], "/api/v1/service_connections/svc_#{connection.id}/access_token"
  end

  test "credential rotation updates encrypted payload without changing authority revision" do
    connection = accounts(:personal_account).service_connections.create!(
      connected_by_user: users(:user_1),
      provider: "oura",
      external_subject_id: "oura-user-1",
      management_scope: "personal",
      credential_kind: "oauth2",
      credential_payload_hash: { "access_token" => "old", "refresh_token" => "refresh" },
      credential_metadata: { "credential_strategy" => "refresh_broker" }
    )

    assert_no_changes -> { connection.reload.credential_revision } do
      connection.replace_credential_payload_without_reconciliation!(
        "access_token" => "new",
        "refresh_token" => "rotated"
      )
    end

    assert_equal "new", connection.credential_payload_hash["access_token"]
    assert_equal "rotated", connection.credential_payload_hash["refresh_token"]
  end

end
