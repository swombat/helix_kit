require "test_helper"

class AuditableTest < ActionDispatch::IntegrationTest

  setup do
    @user = users(:user_1)
    @account = accounts(:personal_account)
  end

  test "login creates audit log" do
    assert_difference "AuditLog.count" do
      post login_path, params: {
        email_address: @user.email_address,
        password: "password123"
      }
    end

    log = AuditLog.last
    assert_equal "login", log.action
    assert_equal @user, log.user
    assert_equal @user, log.auditable
    assert_not_nil log.ip_address
    # User agent might be nil in test environment, which is fine
  end

  test "logout creates audit log" do
    sign_in(@user)

    assert_difference "AuditLog.count" do
      delete logout_path
    end

    log = AuditLog.last
    assert_equal "logout", log.action
    assert_equal @user, log.user
  end

  test "password reset uses audit_as for unauthenticated user" do
    assert_difference "AuditLog.count" do
      post passwords_path, params: {
        email_address: @user.email_address
      }
    end

    log = AuditLog.last
    assert_equal "password_reset_requested", log.action
    assert_equal @user, log.user
    assert_equal @user, log.auditable
  end

  test "audit skips when no user authenticated" do
    initial_count = AuditLog.count

    post login_path, params: {
      email_address: "nonexistent@example.com",
      password: "wrong"
    }

    assert_equal initial_count, AuditLog.count
  end

  test "audit captures account context when set" do
    sign_in(@user)

    # Force account context to be set
    get root_path

    delete logout_path

    log = AuditLog.last
    # Account should be captured from Current.account
    assert_not_nil log.account
  end

end
