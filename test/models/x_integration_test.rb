require "test_helper"
require "support/vcr_setup"

class XIntegrationTest < ActiveSupport::TestCase

  setup do
    @account = accounts(:team_account)
  end

  test "validates uniqueness of account" do
    XIntegration.create!(account: @account, access_token: "t", refresh_token: "rt", token_expires_at: 1.day.from_now)

    duplicate = XIntegration.new(account: @account, access_token: "t2", refresh_token: "rt2")
    assert_not duplicate.valid?
  end

  test "connected? requires access_token and refresh_token" do
    integration = XIntegration.new(account: @account)
    assert_not integration.connected?

    integration.assign_attributes(access_token: "t", refresh_token: "rt")
    assert integration.connected?
  end

  test "disconnect! clears all credentials" do
    integration = XIntegration.create!(
      account: @account,
      access_token: "t", refresh_token: "rt",
      token_expires_at: 1.day.from_now,
      x_username: "bot"
    )

    integration.disconnect!
    integration.reload

    assert_nil integration.access_token
    assert_nil integration.refresh_token
    assert_nil integration.token_expires_at
    assert_nil integration.x_username
    assert_not integration.connected?
  end

  test "enabled scope returns only enabled integrations" do
    XIntegration.create!(account: @account, enabled: true, access_token: "t", refresh_token: "rt")

    assert_equal 1, XIntegration.enabled.count
  end

  test "token_fresh? returns false when expired" do
    integration = XIntegration.new(token_expires_at: 1.minute.from_now)
    assert_not integration.token_fresh?
  end

  test "token_fresh? returns true when well before expiry" do
    integration = XIntegration.new(token_expires_at: 1.hour.from_now)
    assert integration.token_fresh?
  end

end
