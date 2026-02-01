require "test_helper"

class OuraIntegrationTest < ActiveSupport::TestCase

  setup do
    @user = users(:confirmed_user)
    @integration = OuraIntegration.create!(user: @user)
  end

  test "validates uniqueness of user" do
    duplicate = OuraIntegration.new(user: @user)
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:user_id], "has already been taken"
  end

  test "connected? returns true with valid token" do
    @integration.update!(access_token: "token", token_expires_at: 1.day.from_now)
    assert @integration.connected?
  end

  test "connected? returns false with expired token" do
    @integration.update!(access_token: "token", token_expires_at: 1.day.ago)
    assert_not @integration.connected?
  end

  test "connected? returns false without token" do
    assert_not @integration.connected?
  end

  test "health_context returns nil when disabled" do
    @integration.update!(enabled: false, health_data: { "sleep" => [ { "day" => "2026-01-26", "score" => 85 } ] })
    assert_nil @integration.health_context
  end

  test "health_context returns nil when no data" do
    @integration.update!(enabled: true, health_data: {})
    assert_nil @integration.health_context
  end

  test "health_context formats sleep data" do
    @integration.update!(
      enabled: true,
      health_data: {
        "sleep" => [ { "day" => "2026-01-26", "score" => 85, "contributors" => { "deep_sleep" => 70 } } ]
      }
    )

    context = @integration.health_context
    assert_includes context, "Sleep Score: 85/100"
    assert_includes context, "Deep Sleep: 70/100"
  end

  test "health_context formats readiness data" do
    @integration.update!(
      enabled: true,
      health_data: {
        "readiness" => [ { "day" => "2026-01-27", "score" => 72, "contributors" => { "hrv_balance" => 65 }, "temperature_deviation" => -0.2 } ]
      }
    )

    context = @integration.health_context
    assert_includes context, "Readiness Score: 72/100"
    assert_includes context, "HRV Balance: 65/100"
    assert_includes context, "Temperature Deviation: -0.2C"
  end

  test "health_context formats activity data" do
    @integration.update!(
      enabled: true,
      health_data: {
        "activity" => [ { "day" => "2026-01-26", "score" => 82, "steps" => 12345, "active_calories" => 450 } ]
      }
    )

    context = @integration.health_context
    assert_includes context, "Activity Score: 82/100"
    assert_includes context, "Steps: 12,345"
    assert_includes context, "Active Calories: 450"
  end

  test "health_context returns nil when data has no matching keys" do
    @integration.update!(enabled: true, health_data: { "unknown" => "stuff" })
    assert_nil @integration.health_context
  end

  test "disconnect clears all data" do
    @integration.update!(
      access_token: "token",
      refresh_token: "refresh",
      token_expires_at: 1.day.from_now,
      health_data: { "sleep" => [] }
    )

    # Stub revoke_token to avoid HTTP call
    @integration.stub(:revoke_token, nil) do
      @integration.disconnect!
    end

    assert_nil @integration.access_token
    assert_nil @integration.refresh_token
    assert_nil @integration.token_expires_at
    assert_equal({}, @integration.health_data)
  end

end
