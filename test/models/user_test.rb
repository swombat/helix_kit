require "test_helper"

class UserTest < ActiveSupport::TestCase

  # === Core User.register! Method Tests ===

  test "register! creates user, account, and membership for new email" do
    assert_difference [ "User.count", "Account.count", "AccountUser.count" ] do
      user = User.register!("new@example.com")
      assert user.persisted?
      assert user.personal_account.present?
      assert user.personal_account_user.present?
      assert_equal "personal", user.personal_account.account_type
      assert_equal "owner", user.personal_account_user.role
    end
  end

  test "register! handles existing unconfirmed user" do
    # Create an unconfirmed user directly
    existing = User.create!(
      email_address: "existing@example.com",
      confirmed_at: nil
    )
    existing_id = existing.id

    assert_no_difference "User.count" do
      user = User.register!("existing@example.com")
      assert_equal existing_id, user.id
      assert user.personal_account.present?
    end
  end

  test "register! handles existing confirmed user" do
    existing = users(:user_1)
    initial_account_count = existing.accounts.count

    assert_no_difference [ "User.count", "Account.count", "AccountUser.count" ] do
      user = User.register!(existing.email_address)
      assert_equal existing.id, user.id
    end
  end

  test "register! validates email format" do
    invalid_emails = [
      "invalid-email",
      "@example.com",
      "user@",
      "",
      nil
    ]

    invalid_emails.each do |email|
      assert_raises(ActiveRecord::RecordInvalid, "Should reject email: #{email.inspect}") do
        User.register!(email)
      end
    end
  end

  test "register! normalizes email address" do
    user = User.register!("  UPPERCASE@EXAMPLE.COM  ")
    assert_equal "uppercase@example.com", user.email_address
  end

  test "register! returns singleton method was_new_record?" do
    new_user = User.register!("brand-new@example.com")
    assert new_user.was_new_record?

    existing_user = User.register!("brand-new@example.com")
    assert_not existing_user.was_new_record?
  end

  # === find_or_create_membership! Method Tests ===

  test "find_or_create_membership! returns existing membership" do
    user = users(:user_1)
    existing_membership = user.personal_account_user

    result = user.find_or_create_membership!
    assert_equal existing_membership, result
  end

  test "find_or_create_membership! creates membership for user without account" do
    user = User.create!(email_address: "orphan@example.com")
    # Manually remove the account created by callback for this test
    user.account_users.destroy_all
    user.accounts.destroy_all
    user.reload

    assert_nil user.personal_account
    assert_difference [ "Account.count", "AccountUser.count" ] do
      membership = user.find_or_create_membership!
      assert membership.persisted?
      assert_equal "owner", membership.role
      assert_equal "personal", membership.account.account_type
    end
  end

  # === ensure_account_user_exists Callback Tests ===

  test "ensure_account_user_exists creates account and membership on user creation" do
    assert_difference [ "Account.count", "AccountUser.count" ] do
      user = User.create!(email_address: "callback-test@example.com")

      user.reload
      assert user.personal_account.present?
      assert user.personal_account_user.present?
      assert user.default_account.present?
      assert_equal user.personal_account, user.default_account
    end
  end

  test "ensure_account_user_exists sets default_account_id correctly using update_column" do
    user = User.create!(email_address: "default-test@example.com")
    user.reload

    assert user.default_account_id.present?
    assert_equal user.personal_account.id, user.default_account_id
  end

  test "ensure_account_user_exists skips if account_users already exist" do
    user = User.create!(email_address: "existing@example.com")
    initial_count = user.account_users.count

    # Trigger callback again by updating - callback should skip
    user.update!(email_address: "updated@example.com", password: "newpassword", password_confirmation: "newpassword")

    assert_equal initial_count, user.account_users.count
  end

  # === confirmed? and confirm! Methods ===

  test "confirmed? returns true when user has confirmed_at" do
    user = users(:user_1)
    assert user.confirmed?
  end

  test "confirmed? returns true when any account membership is confirmed" do
    user = User.create!(email_address: "account-confirmed@example.com")
    # Clear user-level confirmation but keep AccountUser confirmation
    user.update_column(:confirmed_at, nil)
    user.account_users.first.update!(confirmed_at: Time.current)

    assert user.confirmed?
  end

  test "confirmed? returns false when neither user nor memberships are confirmed" do
    user = User.create!(
      email_address: "unconfirmed-test@example.com",
      confirmed_at: nil
    )
    # Ensure no confirmations exist
    user.account_users.update_all(confirmed_at: nil)

    assert_not user.confirmed?
  end

  test "confirm! clears confirmation_token using update_column" do
    user = User.create!(
      email_address: "to-confirm@example.com",
      confirmed_at: nil
    )
    original_token = user.confirmation_token

    user.confirm!
    user.reload

    # Should clear token first via update_column
    assert_nil user.confirmation_token
    assert_not_equal original_token, user.confirmation_token
  end

  # === Authorization Helper Tests ===

  test "authorization helpers work correctly" do
    user = User.register!("auth-user@example.com")
    account = user.personal_account

    # Confirm the user for testing
    user.account_users.first.confirm!

    assert user.member_of?(account)
    assert user.can_manage?(account)
    assert user.owns?(account)

    # Test with another account
    other_account = Account.create!(name: "Other", account_type: :team)
    assert_not user.member_of?(other_account)
    assert_not user.can_manage?(other_account)
    assert_not user.owns?(other_account)
  end

  # === Critical Update Method Safety Tests (For the bug we fixed) ===

  test "update_column works correctly on User model" do
    user = users(:user_1)
    original_updated_at = user.updated_at

    # Test update_column (should work without callbacks and not update updated_at)
    assert_nothing_raised do
      user.update_column(:email_address, "updated-via-column@example.com")
    end

    user.reload
    assert_equal "updated-via-column@example.com", user.email_address
    assert_equal original_updated_at.to_i, user.updated_at.to_i # Should not change updated_at
  end

  test "update! works correctly on User model" do
    user = users(:user_1)

    # Test update! with required fields
    assert_nothing_raised do
      user.update!(
        email_address: "updated-via-update@example.com",
        password: "newpassword",
        password_confirmation: "newpassword"
      )
    end
    assert_equal "updated-via-update@example.com", user.reload.email_address
  end

  test "save! works correctly on User model" do
    user = User.new(email_address: "save-test@example.com")

    # Test save!
    assert_nothing_raised do
      user.save!
    end
    assert user.persisted?
  end

  # === Validation Tests (Core functionality) ===

  test "validates email_address presence" do
    user = User.new(email_address: "")
    assert_not user.valid?
    assert user.errors[:email_address].include?("can't be blank")
  end

  test "validates email_address uniqueness case insensitive" do
    existing_email = users(:user_1).email_address

    user = User.new(email_address: existing_email.upcase)
    assert_not user.valid?
    assert user.errors[:email_address].include?("has already been taken")
  end

  test "validates password confirmation when password present" do
    user = User.new(
      email_address: "test@example.com",
      password: "password123",
      password_confirmation: "different"
    )

    assert_not user.valid?
    assert user.errors[:password_confirmation].present?
  end

  test "validates password length when password present" do
    user = User.new(email_address: "test@example.com")

    # Too short
    user.password = "12345"
    user.password_confirmation = "12345"
    assert_not user.valid?
    assert user.errors[:password].present?

    # Just right
    user.password = "password123"
    user.password_confirmation = "password123"
    assert user.valid?
  end

  # === Association Tests ===

  test "has_many account_users dependent destroy" do
    user = User.create!(email_address: "destroy-test@example.com")
    account_user_id = user.account_users.first.id

    user.destroy

    assert_not AccountUser.exists?(account_user_id)
  end

  test "personal_account association works correctly" do
    user = users(:user_1)
    personal = user.personal_account

    assert personal.present?
    assert_equal "personal", personal.account_type
    assert_equal user, personal.owner
  end

  # === Business Logic Tests ===

  test "can_login? returns true for confirmed users with password" do
    user = users(:user_1)
    assert user.can_login?
  end

  test "can_login? returns false for users without password" do
    user = users(:no_password_user)
    assert_not user.can_login?
  end

  # === Token Generation Tests ===

  test "generates password reset token" do
    user = users(:user_1)
    token = user.password_reset_token

    assert token.present?
    assert_kind_of String, token
  end

  test "find_by_password_reset_token! finds user with valid token" do
    user = users(:user_1)
    token = user.password_reset_token

    found_user = User.find_by_password_reset_token!(token)
    assert_equal user, found_user
  end

  test "find_by_password_reset_token! raises error for invalid token" do
    assert_raises(ActiveSupport::MessageVerifier::InvalidSignature) do
      User.find_by_password_reset_token!("invalid-token")
    end
  end

  # === Legacy Compatibility Tests ===

  test "backward compatibility with legacy confirm!" do
    # Create user with old system (direct creation)
    user = User.create!(
      email_address: "legacy@example.com",
      confirmed_at: nil
    )

    # User should have AccountUser from after_create callback
    assert user.account_users.exists?
    assert_not user.confirmed?

    # Confirm using legacy method
    user.confirm!
    user.reload

    # Should be confirmed and token cleared
    assert user.confirmed?
    assert_nil user.confirmation_token
  end

  test "sets default account when AccountUser is created" do
    user = User.create!(email_address: "default-account-test@example.com")

    # Should have default account set from after_create callback
    user.reload
    assert user.default_account.present?
    assert_equal user.personal_account, user.default_account
  end

end
