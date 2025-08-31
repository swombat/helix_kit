require "test_helper"

class AccountTest < ActiveSupport::TestCase

  # === Core add_user! Method Tests ===

  test "add_user! creates new AccountUser for new membership" do
    account = accounts(:team_account)
    new_user = User.create!(email_address: "newmember@example.com")

    assert_difference "AccountUser.count" do
      account_user = account.add_user!(new_user, role: "member")
      assert account_user.persisted?
      assert_equal "member", account_user.role
      assert_equal account, account_user.account
      assert_equal new_user, account_user.user
      assert_not account_user.confirmed? # Should require confirmation by default
    end
  end

  test "add_user! with skip_confirmation creates confirmed membership" do
    account = accounts(:team_account)
    new_user = User.create!(email_address: "skipmember@example.com")

    account_user = account.add_user!(new_user, role: "admin", skip_confirmation: true)

    # When skip_confirmation is true, the AccountUser should be confirmed
    # The Confirmable module sets confirmed_at when needs_confirmation? returns false
    account_user.reload
    assert account_user.confirmed?, "AccountUser should be confirmed when skip_confirmation is true"
    assert_nil account_user.confirmation_token
  end

  test "add_user! enforces personal account user limit" do
    personal_account = accounts(:personal_account)
    new_user = User.create!(email_address: "seconduser@example.com")

    # Should fail because personal accounts can only have one user
    assert_raises(ActiveRecord::RecordInvalid) do
      personal_account.add_user!(new_user, role: "owner", skip_confirmation: true)
    end
  end

  # === Personal vs Team Account Tests ===

  test "personal accounts validate single user limit" do
    account = Account.create!(name: "Personal Test", account_type: :personal)
    user1 = User.create!(email_address: "user1@example.com")
    user2 = User.create!(email_address: "user2@example.com")

    # First user should work
    account_user1 = account.add_user!(user1, role: "owner", skip_confirmation: true)
    assert account_user1.persisted?

    # Second user should fail validation
    assert_raises(ActiveRecord::RecordInvalid) do
      account.add_user!(user2, role: "owner", skip_confirmation: true)
    end
  end

  test "team accounts allow multiple users" do
    account = Account.create!(name: "Team Test", account_type: :team)
    user1 = User.create!(email_address: "teamuser1@example.com")
    user2 = User.create!(email_address: "teamuser2@example.com")

    assert_nothing_raised do
      account.add_user!(user1, role: "owner", skip_confirmation: true)
      account.add_user!(user2, role: "member", skip_confirmation: true)
    end

    assert_equal 2, account.users.count
  end

  # === Slug Generation Tests ===

  test "generates slug from name on creation" do
    account = Account.create!(name: "My Test Account", account_type: :personal)
    assert_equal "my-test-account", account.slug
  end

  test "ensures unique slugs by appending random string" do
    Account.create!(name: "Same Name", account_type: :personal)
    account2 = Account.create!(name: "Same Name", account_type: :personal)

    assert_not_equal account2.slug, "same-name"
    assert account2.slug.start_with?("same-name-")
    assert_match(/same-name-[a-f0-9]{8}/, account2.slug)
  end

  test "slug generation handles special characters" do
    account = Account.create!(name: "Test & Account!", account_type: :personal)
    assert_equal "test-account", account.slug
  end

  # === Association Tests ===

  test "has_many account_users dependent destroy" do
    account = Account.create!(name: "Destroy Test", account_type: :team)
    user = User.create!(email_address: "destroytest@example.com")
    account_user = account.add_user!(user, role: "owner", skip_confirmation: true)
    account_user_id = account_user.id

    account.destroy

    assert_not AccountUser.exists?(account_user_id)
  end

  test "has_many users through account_users" do
    account = accounts(:team_account)

    assert account.users.present?
    assert_includes account.users, users(:user_1)
  end

  test "owner association returns owner user" do
    account = accounts(:personal_account)
    owner = users(:user_1)

    assert_equal owner, account.owner
  end

  test "owner_membership association works correctly" do
    account = accounts(:personal_account)
    owner_membership = account.owner_membership

    assert owner_membership.present?
    assert_equal "owner", owner_membership.role
    assert_equal users(:user_1), owner_membership.user
  end

  test "owner association returns nil when no owner exists" do
    account = Account.create!(name: "No Owner Account", account_type: :team)
    user = User.create!(email_address: "member-only@example.com")
    account.add_user!(user, role: "member", skip_confirmation: true)

    assert_nil account.owner
  end

  test "has_many users through account_users includes all confirmed users" do
    account = accounts(:team_account)

    confirmed_users = account.users

    # Should include all confirmed users
    confirmed_users.each do |user|
      membership = account.account_users.find_by(user: user)
      assert membership.confirmed?, "User #{user.email_address} should be confirmed"
    end
  end

  # === Validation Tests ===

  test "validates name presence when not using callback" do
    account = Account.new(name: "Test Account", account_type: :personal)
    assert account.valid?

    account.name = ""
    assert_not account.valid?
    assert account.errors[:name].include?("can't be blank")
  end

  test "validates account_type presence" do
    account = Account.new(name: "Test Account")
    account.account_type = nil
    assert_not account.valid?
    assert account.errors[:account_type].include?("can't be blank")
  end

  # === Enum Tests ===

  test "account_type enum works correctly" do
    personal = Account.create!(name: "Personal", account_type: :personal)
    team = Account.create!(name: "Team", account_type: :team)

    assert personal.personal?
    assert_not personal.team?

    assert team.team?
    assert_not team.personal?
  end

  test "account_type enum scopes work" do
    personal_count = Account.personal.count
    team_count = Account.team.count

    # Create one of each type
    Account.create!(name: "New Personal", account_type: :personal)
    Account.create!(name: "New Team", account_type: :team)

    assert_equal personal_count + 1, Account.personal.count
    assert_equal team_count + 1, Account.team.count
  end

  # === Business Logic Tests ===

  test "personal_account_for? returns true for personal account owner" do
    personal_account = accounts(:personal_account)
    owner = users(:user_1)
    other_user = users(:confirmed_user)

    assert personal_account.personal_account_for?(owner)
    assert_not personal_account.personal_account_for?(other_user)
  end

  test "personal_account_for? returns false for team accounts" do
    team_account = accounts(:team_account)
    user = users(:user_1)

    assert_not team_account.personal_account_for?(user)
  end

  # === Account Type Conversion Tests ===

  test "make_personal! converts team account to personal when single user" do
    account = Account.create!(name: "Solo Team", account_type: :team)
    user = User.create!(email_address: "solo@example.com")
    account.add_user!(user, role: "owner", skip_confirmation: true)

    assert account.team?
    assert account.can_be_personal?

    account.make_personal!

    assert account.personal?
    assert_equal "owner", account.account_users.first.role
  end

  test "make_personal! does nothing for team account with multiple users" do
    account = accounts(:team_account)
    original_type = account.account_type

    account.make_personal!

    assert_equal original_type, account.reload.account_type
  end

  test "make_personal! does nothing for already personal account" do
    account = accounts(:personal_account)
    original_type = account.account_type

    account.make_personal!

    assert_equal original_type, account.reload.account_type
  end

  test "make_team! converts personal account to team with new name" do
    account = accounts(:personal_account)

    assert account.personal?

    account.make_team!("New Team Name")

    assert account.team?
    assert_equal "New Team Name", account.name
  end

  test "make_team! does nothing for already team account" do
    account = accounts(:team_account)
    original_name = account.name

    account.make_team!("Should Not Change")

    assert_equal original_name, account.reload.name
    assert account.team?
  end

  test "can_be_personal? returns true for team with single user" do
    account = Account.create!(name: "Single User Team", account_type: :team)
    user = User.create!(email_address: "singleuser@example.com")
    account.add_user!(user, role: "owner", skip_confirmation: true)

    assert account.can_be_personal?
  end

  test "can_be_personal? returns false for team with multiple users" do
    account = accounts(:team_account)

    assert_not account.can_be_personal?
  end

  test "can_be_personal? returns false for personal account" do
    account = accounts(:personal_account)

    assert_not account.can_be_personal?
  end

  test "can_be_personal? returns false when team has pending invitations" do
    account = accounts(:another_team)  # Has 3 users: one confirmed, one admin, one pending

    # Verify test data assumption
    assert_equal 3, account.account_users.count
    assert account.account_users.where(confirmed_at: nil).exists?, "Should have pending invitations"

    assert_not account.can_be_personal?
  end

  test "make_personal! fails when team has pending invitations" do
    account = accounts(:another_team)  # Has 3 users: one confirmed, one admin, one pending
    original_type = account.account_type

    # Should not convert because total account_users.count > 1
    account.make_personal!

    # Should remain as team account
    assert_equal original_type, account.reload.account_type
    assert account.team?
  end

  test "make_personal! works when all extra users are removed" do
    account = accounts(:another_team)

    # Remove the pending invitation and one confirmed user, leaving only one confirmed user
    pending_invitation = account.account_users.find_by(confirmed_at: nil)
    pending_invitation.destroy!

    # Remove the admin (user_1), keep only the member (user_3)
    admin_membership = account.account_users.find_by(user_id: 1)
    admin_membership.destroy!

    assert_equal 1, account.account_users.count
    assert account.can_be_personal?

    account.make_personal!

    assert account.personal?
    assert_equal "owner", account.account_users.first.role
  end

  test "make_personal! requires exactly one user (not zero)" do
    account = Account.create!(name: "Empty Team", account_type: :team)

    # Team with no users cannot be made personal
    assert_not account.can_be_personal?

    account.make_personal!

    # Should remain team
    assert account.team?
  end

  # === Name Method Override Tests ===

  test "name returns owner's full name for personal accounts when available" do
    user = users(:user_1)
    account = user.personal_account

    expected_name = "#{user.full_name}'s Account"
    assert_equal expected_name, account.name
  end

  test "name falls back to stored name for personal accounts without full name" do
    user = User.create!(email_address: "nonames@example.com")
    account = user.personal_account

    # User has no first_name/last_name, so should use stored name
    assert_equal account.read_attribute(:name), account.name
  end

  test "name returns stored name for team accounts" do
    account = accounts(:team_account)
    stored_name = account.read_attribute(:name)

    assert_equal stored_name, account.name
  end

  # === Dynamic Name Updates ===

  test "personal account name updates when owner name changes" do
    user = users(:user_1)
    account = user.personal_account

    # Update user's name
    user.update!(first_name: "Updated", last_name: "Name", password: "newpass123", password_confirmation: "newpass123")

    assert_equal "Updated Name's Account", account.name
  end

  # === Critical Update Method Safety Tests (For the bug we fixed) ===

  test "update! methods work correctly on Account model" do
    account = accounts(:team_account)

    # Test update!
    assert_nothing_raised do
      account.update!(name: "Updated Team Name")
    end
    assert_equal "Updated Team Name", account.reload.name
  end

  test "update_column works correctly on Account model" do
    account = accounts(:team_account)
    original_updated_at = account.updated_at

    # Test update_column (should work without callbacks and not update updated_at)
    assert_nothing_raised do
      account.update_column(:name, "Column Updated Name")
    end

    account.reload
    assert_equal "Column Updated Name", account.name
    assert_equal original_updated_at.to_i, account.updated_at.to_i # Should not change updated_at
  end

  test "save! works correctly on Account model" do
    account = Account.new(name: "Save Test", account_type: :team)

    # Test save!
    assert_nothing_raised do
      account.save!
    end
    assert account.persisted?
  end

  # === Settings JSON Column Tests ===

  test "settings defaults to empty hash" do
    account = Account.create!(name: "Settings Test", account_type: :personal)
    assert_equal({}, account.settings)
  end

  test "settings can store JSON data" do
    account = Account.create!(
      name: "Settings Test",
      account_type: :team,
      settings: { theme: "dark", notifications: true }
    )

    account.reload
    assert_equal "dark", account.settings["theme"]
    assert_equal true, account.settings["notifications"]
  end

  # === is_site_admin Tests ===

  test "as_json includes is_site_admin field" do
    account = accounts(:personal_account)
    account.update_column(:is_site_admin, true)

    json = account.as_json
    assert json.key?("is_site_admin")
    assert_equal true, json["is_site_admin"]
  end

  test "as_json includes is_site_admin as false when not set" do
    account = accounts(:personal_account)
    account.update_column(:is_site_admin, false)

    json = account.as_json
    assert json.key?("is_site_admin")
    assert_equal false, json["is_site_admin"]
  end

end
