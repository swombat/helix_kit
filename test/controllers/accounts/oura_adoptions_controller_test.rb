require "test_helper"

class Accounts::OuraAdoptionsControllerTest < ActionDispatch::IntegrationTest

  setup do
    @user = users(:user_1)
    @account = accounts(:personal_account)
    @integration = @user.create_oura_integration!(
      access_token: "working-access-token",
      refresh_token: "working-refresh-token",
      token_expires_at: 2.days.from_now,
      health_data: { "sleep" => [ { "day" => Date.current.to_s, "score" => 88 } ] },
      health_data_synced_at: 1.hour.ago
    )
    sign_in @user
  end

  test "adoption references the legacy row without changing encrypted credentials" do
    before = raw_oura_values

    assert_difference "ServiceConnection.count", 1 do
      post account_oura_adoption_path(@account)
    end

    assert_redirected_to account_personal_services_path(@account)
    connection = @account.service_connections.find_by!(legacy_oura_integration: @integration)
    assert_equal "oura", connection.provider
    assert_equal "legacy_reference", connection.credential_kind
    assert_nil connection.credential_payload
    assert_equal before, raw_oura_values
    assert_equal "working-access-token", @integration.reload.access_token
    assert_equal "working-refresh-token", @integration.refresh_token
  end

  test "removing resident access preserves the legacy row and its encrypted credentials" do
    post account_oura_adoption_path(@account)
    connection = @account.service_connections.find_by!(legacy_oura_integration: @integration)
    before = raw_oura_values

    assert_no_difference "OuraIntegration.count" do
      delete account_service_connection_path(@account, connection.public_id),
             headers: { "HTTP_REFERER" => account_personal_services_url(@account) }
    end

    assert_redirected_to account_personal_services_path(@account)
    assert_not ServiceConnection.exists?(connection.id)
    assert OuraIntegration.exists?(@integration.id)
    assert_equal before, raw_oura_values
    assert_equal "working-access-token", @integration.reload.access_token
    assert_equal "working-refresh-token", @integration.refresh_token
  end

  test "the same rotating Oura credential cannot be adopted into a second account" do
    post account_oura_adoption_path(@account)
    before = raw_oura_values

    assert_no_difference "ServiceConnection.count" do
      post account_oura_adoption_path(accounts(:team_account))
    end

    assert_redirected_to account_personal_services_path(accounts(:team_account))
    assert_equal before, raw_oura_values
    assert_equal @account, @integration.reload.service_connection.account
  end

  private

  def raw_oura_values
    OuraIntegration.connection.select_one(<<~SQL.squish)
      SELECT access_token, refresh_token, token_expires_at, health_data, health_data_synced_at
      FROM oura_integrations
      WHERE id = #{@integration.id}
    SQL
  end

end
