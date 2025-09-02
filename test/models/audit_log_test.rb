require "test_helper"

class AuditLogTest < ActiveSupport::TestCase

  setup do
    @user = users(:user_1)
    @account = accounts(:personal_account)
  end

  test "creates audit log with all attributes" do
    log = AuditLog.create!(
      user: @user,
      account: @account,
      action: :test_action,
      auditable: @user,
      data: { test: "data" },
      ip_address: "127.0.0.1",
      user_agent: "Test Browser"
    )

    assert log.persisted?
    assert_equal @user, log.user
    assert_equal @account, log.account
    assert_equal "test_action", log.action
    assert_equal({ "test" => "data" }, log.data)
    assert_equal "127.0.0.1", log.ip_address
    assert_equal "Test Browser", log.user_agent
  end

  test "allows nil user for system actions" do
    log = AuditLog.create!(
      action: :system_cleanup
    )

    assert log.persisted?
    assert_nil log.user
  end

  test "allows nil account for non-account actions" do
    log = AuditLog.create!(
      user: @user,
      action: :login
    )

    assert log.persisted?
    assert_nil log.account
  end

  test "allows nil auditable" do
    log = AuditLog.create!(
      user: @user,
      account: @account,
      action: :logout
    )

    assert log.persisted?
    assert_nil log.auditable
  end

  test "requires action" do
    log = AuditLog.new(user: @user)

    assert_not log.valid?
    assert_includes log.errors[:action], "can't be blank"
  end

  test "display_action humanizes the action" do
    log = AuditLog.new(action: "change_theme")
    assert_equal "Change theme", log.display_action
  end

  test "display_action handles underscores" do
    log = AuditLog.new(action: "invite_team_member")
    assert_equal "Invite team member", log.display_action
  end

  test "recent scope orders by created_at desc" do
    old_log = AuditLog.create!(action: :old_action, created_at: 2.days.ago)
    new_log = AuditLog.create!(action: :new_action, created_at: 1.day.ago)

    recent_logs = AuditLog.recent
    assert_equal new_log, recent_logs.first
    assert_equal old_log, recent_logs.second
  end

  test "for_account scope filters by account" do
    other_account = accounts(:team_account)

    log1 = AuditLog.create!(user: @user, account: @account, action: :action1)
    log2 = AuditLog.create!(user: @user, account: other_account, action: :action2)
    log3 = AuditLog.create!(user: @user, action: :action3) # No account

    account_logs = AuditLog.for_account(@account)

    assert_includes account_logs, log1
    assert_not_includes account_logs, log2
    assert_not_includes account_logs, log3
  end

  test "for_user scope filters by user" do
    other_user = users(:existing_user)

    log1 = AuditLog.create!(user: @user, action: :action1)
    log2 = AuditLog.create!(user: other_user, action: :action2)
    log3 = AuditLog.create!(action: :action3) # No user

    user_logs = AuditLog.for_user(@user)

    assert_includes user_logs, log1
    assert_not_includes user_logs, log2
    assert_not_includes user_logs, log3
  end

  test "jsonb data field works correctly" do
    complex_changes = {
      "from" => { "theme" => "light", "timezone" => "UTC" },
      "to" => { "theme" => "dark", "timezone" => "America/New_York" },
      "metadata" => [ "extra", "info" ]
    }

    log = AuditLog.create!(
      user: @user,
      action: :update_settings,
      data: complex_changes
    )

    log.reload
    assert_equal complex_changes, log.data
  end

  test "polymorphic auditable association works" do
    # Test with User
    user_log = AuditLog.create!(action: :test, auditable: @user)
    user_log.reload
    assert_equal @user, user_log.auditable
    assert_equal "User", user_log.auditable_type

    # Test with Account
    account_log = AuditLog.create!(action: :test, auditable: @account)
    account_log.reload
    assert_equal @account, account_log.auditable
    assert_equal "Account", account_log.auditable_type
  end

end
