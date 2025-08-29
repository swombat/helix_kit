require "test_helper"

class AccountUserTest < ActiveSupport::TestCase

  # === Core confirm_by_token! Class Method Tests ===

  test "confirm_by_token! finds and confirms AccountUser with valid token" do
    account_user = account_users(:pending_invitation)
    token = account_user.confirmation_token

    confirmed = AccountUser.confirm_by_token!(token)

    assert_equal account_user, confirmed
    assert confirmed.confirmed?
    assert_nil confirmed.confirmation_token
  end

  test "confirm_by_token! raises error for invalid token" do
    assert_raises(ActiveSupport::MessageVerifier::InvalidSignature) do
      AccountUser.confirm_by_token!("invalid-token")
    end
  end

  test "confirm_by_token! raises error for nil token" do
    assert_raises(ActiveSupport::MessageVerifier::InvalidSignature) do
      AccountUser.confirm_by_token!(nil)
    end
  end

  # === Core set_user_default_account Callback Tests ===

  test "set_user_default_account sets default_account_id when user has no default" do
    user = User.create!(email_address: "nodefault@example.com")
    # Remove default set by User callback
    user.update_column(:default_account_id, nil)
    account = accounts(:team_account)

    account_user = AccountUser.create!(
      user: user,
      account: account,
      role: "member",
      skip_confirmation: true
    )

    user.reload
    assert_equal account.id, user.default_account_id
  end

  test "set_user_default_account does not override existing default_account_id" do
    user = users(:user_1)
    original_default_id = user.default_account_id
    different_account = accounts(:team_account)

    AccountUser.create!(
      user: user,
      account: different_account,
      role: "member",
      skip_confirmation: true
    )

    user.reload
    assert_equal original_default_id, user.default_account_id
  end

  test "set_user_default_account uses update_column correctly" do
    user = User.create!(email_address: "updatecolumn@example.com")
    user.update_column(:default_account_id, nil)
    account = accounts(:team_account)
    original_updated_at = user.updated_at

    AccountUser.create!(
      user: user,
      account: account,
      role: "member",
      skip_confirmation: true
    )

    user.reload
    assert_equal account.id, user.default_account_id
    # update_column should not change updated_at
    assert_equal original_updated_at.to_i, user.updated_at.to_i
  end

  # === Role Validation Tests ===

  test "validates role inclusion" do
    account = accounts(:team_account)

    # Valid roles should work - use different users for each
    %w[owner admin member].each_with_index do |role, index|
      user = User.create!(email_address: "test#{index}@example.com")
      account_user = AccountUser.new(account: account, user: user, role: role)
      account_user.skip_confirmation = true
      assert account_user.valid?, "#{role} should be valid"
    end

    # Invalid role should fail
    user = User.create!(email_address: "invalid@example.com")
    account_user = AccountUser.new(account: account, user: user, role: "invalid")
    account_user.skip_confirmation = true
    assert_not account_user.valid?
    assert account_user.errors[:role].present?
  end

  test "enforces personal account role restrictions" do
    account = accounts(:personal_account)
    user = User.create!(email_address: "roletest@example.com")

    # Member role should fail for personal account
    account_user = AccountUser.new(account: account, user: user, role: "member")
    account_user.skip_confirmation = true
    assert_not account_user.valid?
    assert account_user.errors[:role].include?("must be owner for personal accounts")

    # Owner role should work
    account_user.role = "owner"
    # But will still fail due to single user limit - that's expected
    assert_not account_user.valid?
    assert account_user.errors[:base].include?("Personal accounts can only have one user")
  end

  # === Uniqueness Validation Tests ===

  test "prevents duplicate user per account" do
    account = accounts(:team_account)
    user = users(:confirmed_user)

    # First membership should work
    account_user1 = AccountUser.create!(
      account: account,
      user: user,
      role: "owner",
      skip_confirmation: true
    )
    assert account_user1.persisted?

    # Second membership should fail
    account_user2 = AccountUser.new(account: account, user: user, role: "member")
    account_user2.skip_confirmation = true
    assert_not account_user2.valid?
    assert account_user2.errors[:user_id].include?("is already a member of this account")
  end

  test "allows same user across different accounts" do
    user = users(:confirmed_user)
    account1 = accounts(:team_account)
    account2 = accounts(:another_team)

    assert_nothing_raised do
      AccountUser.create!(account: account1, user: user, role: "admin", skip_confirmation: true)
      AccountUser.create!(account: account2, user: user, role: "member", skip_confirmation: true)
    end

    assert user.account_users.count >= 2
  end

  # === Role Helper Methods Tests ===

  test "role helper methods work correctly" do
    account = accounts(:team_account)
    user = User.create!(email_address: "rolehelper@example.com")

    # Test owner
    owner = AccountUser.create!(
      account: account, user: user, role: "owner", skip_confirmation: true
    )
    assert owner.owner?
    assert owner.admin?
    assert owner.can_manage?

    # Test admin
    admin_user = User.create!(email_address: "admin@example.com")
    admin = AccountUser.create!(
      account: account, user: admin_user, role: "admin", skip_confirmation: true
    )
    assert_not admin.owner?
    assert admin.admin?
    assert admin.can_manage?

    # Test member
    member_user = User.create!(email_address: "member@example.com")
    member = AccountUser.create!(
      account: account, user: member_user, role: "member", skip_confirmation: true
    )
    assert_not member.owner?
    assert_not member.admin?
    assert_not member.can_manage?
  end

  # === Scopes Tests ===

  test "confirmation scopes work correctly" do
    account = accounts(:team_account)
    user1 = User.create!(email_address: "confirmed@example.com")
    user2 = User.create!(email_address: "unconfirmed@example.com")

    # Confirmed user
    confirmed = AccountUser.create!(
      account: account,
      user: user1,
      role: "owner",
      confirmed_at: Time.current,
      skip_confirmation: true
    )

    # Unconfirmed user
    unconfirmed = AccountUser.create!(
      account: account,
      user: user2,
      role: "member",
      confirmed_at: nil,
      skip_confirmation: true
    )

    assert_includes AccountUser.confirmed, confirmed
    assert_not_includes AccountUser.confirmed, unconfirmed

    assert_includes AccountUser.unconfirmed, unconfirmed
    assert_not_includes AccountUser.unconfirmed, confirmed
  end

  test "owners scope returns only owner role AccountUsers" do
    owners = AccountUser.owners

    owners.each do |au|
      assert_equal "owner", au.role
    end
  end

  test "admins scope returns owner and admin roles" do
    admins = AccountUser.admins

    admins.each do |au|
      assert au.role.in?(%w[owner admin])
    end
  end

  # === Association Tests ===

  test "belongs_to account and user" do
    account_user = account_users(:daniel_personal)

    assert_equal accounts(:personal_account), account_user.account
    assert_equal users(:user_1), account_user.user
  end

  test "belongs_to invited_by optional" do
    account_user = account_users(:pending_invitation)
    assert_equal users(:user_1), account_user.invited_by

    # Should work without invited_by
    new_user = User.create!(email_address: "noinviter@example.com")
    account_user = AccountUser.create!(
      account: accounts(:team_account),
      user: new_user,
      role: "member",
      skip_confirmation: true
    )
    assert_nil account_user.invited_by
  end

  # === Confirmation Logic Tests ===

  test "confirmed? method from Confirmable module" do
    confirmed = account_users(:daniel_personal)
    unconfirmed = account_users(:pending_invitation)

    assert confirmed.confirmed?
    assert_not unconfirmed.confirmed?
  end

  test "confirm! method from Confirmable module works" do
    account_user = account_users(:pending_invitation)

    assert_not account_user.confirmed?

    account_user.confirm!

    assert account_user.confirmed?
    assert_nil account_user.confirmation_token
    assert account_user.confirmed_at.present?
  end

  # === Critical Update Method Safety Tests (For the bug we fixed) ===

  test "update! methods work correctly on AccountUser model" do
    account_user = account_users(:team_admin)

    # Test update!
    assert_nothing_raised do
      account_user.update!(role: "member")
    end
    assert_equal "member", account_user.reload.role
  end

  test "update_column works correctly on AccountUser model" do
    account_user = account_users(:team_admin)
    original_updated_at = account_user.updated_at

    # Test update_column (should work without callbacks and not update updated_at)
    assert_nothing_raised do
      account_user.update_column(:role, "member")
    end

    account_user.reload
    assert_equal "member", account_user.role
    assert_equal original_updated_at.to_i, account_user.updated_at.to_i # Should not change updated_at
  end

  test "save! works correctly on AccountUser model" do
    account = accounts(:team_account)
    user = User.create!(email_address: "savetest@example.com")
    account_user = AccountUser.new(account: account, user: user, role: "member", skip_confirmation: true)

    # Test save!
    assert_nothing_raised do
      account_user.save!
    end
    assert account_user.persisted?
  end

  # === Confirmation Token Handling Tests ===

  test "confirmation token is generated on create when needed" do
    account = accounts(:team_account)
    user = User.create!(email_address: "tokentest@example.com")

    account_user = AccountUser.create!(
      account: account,
      user: user,
      role: "member"
      # skip_confirmation not set, so token should be generated
    )

    assert account_user.confirmation_token.present?
    assert account_user.confirmation_sent_at.present?
    assert_not account_user.confirmed?
  end

  test "confirmation token is not generated when skip_confirmation is true" do
    account = accounts(:team_account)
    user = User.create!(email_address: "skiptoken@example.com")

    account_user = AccountUser.create!(
      account: account,
      user: user,
      role: "member",
      skip_confirmation: true
    )

    assert_nil account_user.confirmation_token
    assert_nil account_user.confirmation_sent_at
    assert account_user.confirmed?
  end

  # === Validation Edge Cases ===

  test "validates required associations" do
    # Missing account
    account_user = AccountUser.new(user: users(:user_1), role: "owner")
    assert_not account_user.valid?
    assert account_user.errors[:account].present?

    # Missing user
    account_user = AccountUser.new(account: accounts(:team_account), role: "owner")
    assert_not account_user.valid?
    assert account_user.errors[:user].present?
  end

  test "role cannot be blank" do
    account_user = AccountUser.new(
      account: accounts(:team_account),
      user: users(:confirmed_user),
      role: ""
    )

    assert_not account_user.valid?
    assert account_user.errors[:role].present?
  end

  # === Business Logic Integration Tests ===

  test "confirmation workflow end-to-end" do
    # Create unconfirmed AccountUser
    account = accounts(:team_account)
    user = User.create!(email_address: "workflow@example.com")

    account_user = AccountUser.create!(
      account: account,
      user: user,
      role: "member",
      invited_by: users(:user_1)
    )

    # Should be unconfirmed with token
    assert_not account_user.confirmed?
    assert account_user.confirmation_token.present?

    # Confirm by token
    token = account_user.confirmation_token
    confirmed = AccountUser.confirm_by_token!(token)

    assert_equal account_user, confirmed
    assert confirmed.confirmed?
    assert_nil confirmed.confirmation_token
  end

end
