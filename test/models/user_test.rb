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
    email = "existing-#{rand(10000)}@example.com"
    existing = User.create!(
      email_address: email
    )
    existing_id = existing.id

    assert_no_difference "User.count" do
      user = User.register!(email)
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

  test "ensure_account_user_exists skips if account_users already exist" do
    user = User.create!(email_address: "existing-#{rand(10000)}@example.com")
    initial_count = user.account_users.count

    # Trigger callback again by updating - callback should skip
    user.update!(email_address: "updated-#{rand(10000)}@example.com", password: "newpassword", password_confirmation: "newpassword")

    assert_equal initial_count, user.account_users.count
  end

  # === confirmed? and confirm! Methods ===

  test "confirmed? returns true when user has confirmed account membership" do
    user = users(:user_1)
    assert user.confirmed?
  end

  test "confirmed? returns true when any account membership is confirmed" do
    user = User.create!(email_address: "account-confirmed@example.com")
    # AccountUser is created automatically and needs confirmation
    user.account_users.first.update!(confirmed_at: Time.current)

    assert user.confirmed?
  end

  test "confirmed? returns false when no memberships are confirmed" do
    user = User.create!(
      email_address: "unconfirmed-test@example.com"
    )
    # Ensure no confirmations exist
    user.account_users.update_all(confirmed_at: nil)

    assert_not user.confirmed?
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

  test "member_of? requires confirmed membership" do
    user = User.create!(email_address: "member-test@example.com")
    account = Account.create!(name: "Test Account", account_type: :team)

    # Add unconfirmed membership
    account_user = account.add_user!(user, role: "member")
    assert_not account_user.confirmed?

    # Should not be considered a member while unconfirmed
    assert_not user.member_of?(account)

    # Confirm and test again
    account_user.confirm!
    assert user.member_of?(account)
  end

  test "can_manage? returns true for owners and admins only" do
    team_account = Account.create!(name: "Management Test", account_type: :team)

    # Test owner
    owner = User.create!(email_address: "owner-#{rand(10000)}@example.com")
    team_account.add_user!(owner, role: "owner", skip_confirmation: true)
    assert owner.can_manage?(team_account)

    # Test admin
    admin = User.create!(email_address: "admin-#{rand(10000)}@example.com")
    team_account.add_user!(admin, role: "admin", skip_confirmation: true)
    assert admin.can_manage?(team_account)

    # Test member
    member = User.create!(email_address: "member-#{rand(10000)}@example.com")
    team_account.add_user!(member, role: "member", skip_confirmation: true)
    assert_not member.can_manage?(team_account)
  end

  test "owns? returns true only for owners" do
    team_account = Account.create!(name: "Ownership Test", account_type: :team)

    # Test owner
    owner = User.create!(email_address: "test-owner@example.com")
    team_account.add_user!(owner, role: "owner", skip_confirmation: true)
    assert owner.owns?(team_account)

    # Test admin (should not own)
    admin = User.create!(email_address: "test-admin@example.com")
    team_account.add_user!(admin, role: "admin", skip_confirmation: true)
    assert_not admin.owns?(team_account)
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
        password_confirmation: "newpassword",
        first_name: "Updated",
        last_name: "User"
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
    user = User.new(
      email_address: "test-#{rand(10000)}@example.com",
      first_name: "Test",
      last_name: "User"
    )

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

  test "has_many accounts through account_users" do
    user = users(:user_1)

    assert user.accounts.present?
    assert_includes user.accounts, user.personal_account
    assert user.accounts.all? { |account| account.is_a?(Account) }
  end

  test "personal_account association works correctly" do
    user = users(:user_1)
    personal = user.personal_account

    assert personal.present?
    assert_equal "personal", personal.account_type
    assert_equal user, personal.owner
  end

  test "personal_account_user association works correctly" do
    user = users(:user_1)
    personal_account_user = user.personal_account_user

    assert personal_account_user.present?
    assert_equal user, personal_account_user.user
    assert_equal user.personal_account, personal_account_user.account
    assert_equal "owner", personal_account_user.role
  end

  test "default_account returns confirmed account or fallback" do
    user = users(:user_1)

    # Should return the first confirmed account
    assert_equal user.personal_account, user.default_account

    # Test with unconfirmed user
    unconfirmed = users(:unconfirmed_user)
    unconfirmed.account_users.update_all(confirmed_at: nil)

    # Should still return an account even if unconfirmed
    assert unconfirmed.default_account.present?
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

  # === site_admin and is_site_admin? Tests ===

  test "site_admin returns true when user has is_site_admin set" do
    user = users(:user_1)
    user.update_column(:is_site_admin, true)

    assert user.site_admin
  end

  test "is_site_admin? alias method works correctly" do
    user = users(:user_1)
    user.update_column(:is_site_admin, true)

    assert user.is_site_admin?

    user.update_column(:is_site_admin, false)
    assert_not user.is_site_admin?
  end

  test "site_admin returns false when user does not have is_site_admin set" do
    user = users(:user_1)
    user.update_column(:is_site_admin, false)

    assert_not user.site_admin
  end

  test "site_admin returns true when user belongs to account with is_site_admin" do
    user = users(:user_1)
    user.update_column(:is_site_admin, false)

    # Set the account as site admin
    account = user.personal_account
    account.update_column(:is_site_admin, true)

    assert user.site_admin
  end

  test "site_admin returns true when user belongs to site admin account" do
    user = User.create!(email_address: "member-admin@example.com")
    user.update_column(:is_site_admin, false)

    # Create an account with site admin privileges
    admin_account = Account.create!(name: "Admin Account", account_type: :team, is_site_admin: true)

    # Add user as member
    admin_account.add_user!(user, role: "member", skip_confirmation: true)

    assert user.site_admin
  end

  test "site_admin returns false when user only belongs to non-admin accounts" do
    user = User.create!(email_address: "regular-user@example.com")
    user.update_column(:is_site_admin, false)

    # User's personal account should not be site admin
    user.personal_account.update_column(:is_site_admin, false)

    # Add to a regular team account
    regular_account = Account.create!(name: "Regular Account", account_type: :team, is_site_admin: false)
    regular_account.add_user!(user, role: "member", skip_confirmation: true)

    assert_not user.site_admin
  end

  test "as_json includes site_admin field" do
    user = users(:user_1)
    user.update_column(:is_site_admin, true)

    json = user.as_json
    assert json.key?("site_admin")
    assert_equal true, json["site_admin"]
  end

  # === Theme Preferences Tests ===

  test "theme defaults to system for new users" do
    user = User.new(email_address: "theme-test@example.com")
    assert_equal "system", user.theme
  end

  test "theme can be set to valid values" do
    user = users(:user_1)

    [ "light", "dark", "system" ].each do |theme|
      user.theme = theme
      assert user.valid?, "Theme '#{theme}' should be valid"
      assert_equal theme, user.theme
    end
  end

  test "theme validation rejects invalid values" do
    user = users(:user_1)

    [ "invalid", "blue", "auto", "" ].each do |invalid_theme|
      user.theme = invalid_theme
      assert_not user.valid?, "Theme '#{invalid_theme}' should be invalid"
      assert user.errors[:theme].present?
    end
  end

  test "theme allows nil values" do
    user = users(:user_1)
    user.theme = nil
    assert user.valid?
  end

  test "preferences are stored as JSON" do
    user = users(:user_1)
    user.theme = "dark"
    user.save!

    user.reload
    assert_equal "dark", user.theme
    assert_equal({ "theme" => "dark" }, user.preferences)
  end

  test "as_json includes preferences" do
    user = users(:user_1)
    user.theme = "light"
    user.save!

    json = user.as_json
    assert json.key?("preferences")
    assert_equal({ "theme" => "light" }, json["preferences"])
  end

  # === Full Name and Display Tests ===

  test "full_name returns combined first and last name" do
    user = users(:user_1)
    assert_equal "Test User", user.full_name
  end

  test "full_name handles missing names gracefully" do
    user = User.new(email_address: "noname@example.com")
    assert_equal "noname@example.com", user.full_name # Returns email when no name
  end

  test "full_name handles partial names" do
    user = User.new(
      email_address: "partial@example.com",
      first_name: "John",
      last_name: nil
    )
    assert_equal "John", user.full_name # Strip removes trailing space
  end

  # === Complex Site Admin Scenarios ===

  test "site_admin works with multiple account memberships" do
    user = User.create!(email_address: "multi-member@example.com")
    user.update_column(:is_site_admin, false)

    # Add to regular team account
    regular_account = Account.create!(name: "Regular Team", account_type: :team, is_site_admin: false)
    regular_account.add_user!(user, role: "member", skip_confirmation: true)

    assert_not user.site_admin

    # Add to site admin account
    admin_account = Account.create!(name: "Admin Team", account_type: :team, is_site_admin: true)
    admin_account.add_user!(user, role: "member", skip_confirmation: true)

    assert user.site_admin
  end

  test "site_admin prioritizes individual user flag over account flag" do
    user = User.create!(email_address: "priority-test@example.com")
    user.update_column(:is_site_admin, true)

    # Even if personal account is not admin, user should be admin
    user.personal_account.update_column(:is_site_admin, false)

    assert user.site_admin
    assert user.is_site_admin?
  end

  # === Edge Case Tests ===

  test "user without personal account still functions" do
    user = User.create!(email_address: "orphan@example.com")

    # Manually remove personal account for edge case testing
    user.account_users.destroy_all
    user.accounts.destroy_all
    user.reload

    assert_nil user.personal_account
    assert_nil user.personal_account_user
    assert_nil user.default_account
    assert_not user.confirmed?
    assert_not user.can_login?
  end

  # === Invitation System Tests ===

  test "created_via_invitation? returns true for unconfirmed users with invitations" do
    # Use find_or_invite to create a user without a personal account
    user = User.find_or_invite("invitedtest@example.com")

    # Remove the auto-created personal account
    user.account_users.destroy_all

    account = accounts(:team)

    AccountUser.create!(
      account: account,
      user: user,
      role: "member",
      invited_by: users(:admin)
    )

    # Reload to get fresh associations
    user.reload

    assert user.created_via_invitation?
  end

  test "created_via_invitation? returns false for confirmed users" do
    user = users(:owner)
    assert_not user.created_via_invitation?
  end

  test "password validation skipped for users created via invitation" do
    user = User.new(email_address: "invited@example.com")

    # Create invitation without password
    AccountUser.create!(
      account: accounts(:team),
      user: user,
      role: "member",
      invited_by: users(:admin)
    )

    # User should be valid without password
    assert user.valid?
  end

  test "password validation required for non-invited users" do
    user = User.new(email_address: "regular@example.com", password: "short")

    # Should validate password length for regular users
    assert_not user.valid?
    assert_includes user.errors[:password], "is too short (minimum is 8 characters)"
  end

  test "find_or_invite creates user without password" do
    assert_difference "User.count" do
      user = User.find_or_invite("brandnew@example.com")
      assert user.persisted?
      assert_nil user.password_digest
    end
  end

  test "find_or_invite finds existing user" do
    existing = users(:owner)

    assert_no_difference "User.count" do
      user = User.find_or_invite(existing.email_address)
      assert_equal existing, user
    end
  end

  test "full_name returns email when name is blank" do
    user = User.new(
      email_address: "nofullname@example.com",
      first_name: "",
      last_name: ""
    )

    assert_equal "nofullname@example.com", user.full_name
  end

end
