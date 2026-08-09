require "test_helper"
require Rails.root.join("db/migrate/20260809203000_migrate_oura_credentials_to_service_connections")

class MigrateOuraCredentialsToServiceConnectionsTest < ActiveSupport::TestCase

  test "moves legacy credentials into Nexus and provisions every resident" do
    user = users(:user_1)
    nexus = accounts(:team_account)
    nexus.update!(name: "Nexus", slug: "nexus")
    integration = user.create_oura_integration!(
      access_token: "legacy-access",
      refresh_token: "legacy-refresh",
      token_expires_at: 2.days.from_now
    )
    connection = nexus.service_connections.create!(
      connected_by_user: user,
      legacy_oura_integration: integration,
      provider: "oura",
      management_scope: "personal",
      credential_kind: "oauth2",
      status: "connected"
    )
    previously_disabled_access = connection.agent_service_accesses.create!(
      agent: nexus.agents.first,
      enabled: false,
      follows_default: false
    )

    MigrateOuraCredentialsToServiceConnections.new.up

    connection = nexus.service_connections.find_by!(provider: "oura", connected_by_user: user)
    assert_equal "legacy-access", connection.credential_payload_hash["access_token"]
    assert_equal "legacy-refresh", connection.credential_payload_hash["refresh_token"]
    assert connection.enabled_for_new_agents?
    assert connection.freely_provisionable?
    assert_equal nexus.agents.order(:id).pluck(:id), connection.agent_service_accesses.enabled.order(:agent_id).pluck(:agent_id)
    assert previously_disabled_access.reload.enabled?
    assert previously_disabled_access.follows_default?
    assert_nil integration.reload.access_token
    assert_nil integration.refresh_token
  end

end
