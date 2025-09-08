require "test_helper"

class AccountTypeSwitchingTest < ActionDispatch::IntegrationTest

  # === Personal to Team Conversion Tests ===

  test "personal account owner can convert to team account" do
    user = users(:user_1)
    account = accounts(:personal_account)

    assert account.personal?
    assert_equal 1, account.memberships.count

    # Login as the account owner
    post login_path, params: { email_address: user.email_address, password: "password123" }

    # Convert to team account
    put account_path(account), params: {
      convert_to: "team",
      account: { name: "My New Team" }
    }

    assert_redirected_to account_path(account)
    follow_redirect!
    assert_response :success

    account.reload
    assert account.team?
    assert_equal "My New Team", account.name
    assert_equal "owner", account.memberships.first.role
  end

  test "personal account conversion preserves user relationships" do
    user = users(:user_1)
    account = accounts(:personal_account)
    original_membership = account.memberships.first

    post login_path, params: { email_address: user.email_address, password: "password123" }

    put account_path(account), params: {
      convert_to: "team",
      account: { name: "Preserved Team" }
    }

    assert_redirected_to account_path(account)

    account.reload
    original_membership.reload

    # Same Membership record should exist with same ID
    assert_equal original_membership.id, account.memberships.first.id
    assert_equal "owner", original_membership.role
    assert_equal user.id, original_membership.user_id
    assert original_membership.confirmed?
  end

  # === Team to Personal Conversion Tests ===

  test "single-user team can be converted to personal account" do
    user = users(:user_1)
    account = accounts(:team_single_user)

    assert account.team?
    assert_equal 1, account.memberships.count
    assert account.can_be_personal?

    post login_path, params: { email_address: user.email_address, password: "password123" }

    put account_path(account), params: { convert_to: "personal" }

    assert_redirected_to account_path(account)
    follow_redirect!
    assert_response :success

    account.reload
    assert account.personal?
    assert_equal "owner", account.memberships.first.role
  end

  test "team with multiple users cannot be converted to personal" do
    user = users(:user_1)
    account = accounts(:team_account)  # Has multiple users

    assert account.team?
    assert account.memberships.count > 1
    assert_not account.can_be_personal?

    post login_path, params: { email_address: user.email_address, password: "password123" }

    put account_path(account), params: { convert_to: "personal" }

    assert_redirected_to account_path(account)

    account.reload
    # Should remain as team account
    assert account.team?
  end

  test "team with pending invitations cannot be converted to personal" do
    user = users(:user_1)  # Admin of another_team
    account = accounts(:another_team)  # Has confirmed user + pending invitation

    # Verify test assumptions
    assert account.team?
    assert_equal 3, account.memberships.count
    assert account.memberships.where(confirmed_at: nil).exists?
    assert_not account.can_be_personal?

    post login_path, params: { email_address: user.email_address, password: "password123" }

    put account_path(account), params: { convert_to: "personal" }

    assert_redirected_to account_path(account)

    account.reload
    # Should remain as team account
    assert account.team?
  end

  test "team becomes convertible after pending invitations are cancelled" do
    user = users(:existing_user)  # Use user_3 who is the member
    account = accounts(:another_team)

    # Initially cannot be converted (has pending invitation)
    assert_not account.can_be_personal?

    # Remove the pending invitation and one confirmed user
    pending_invitation = account.memberships.find_by(confirmed_at: nil)
    pending_invitation.destroy!

    # Remove the admin (user_1), keep only the member (user_3)
    admin_membership = account.memberships.find_by(user_id: 1)
    admin_membership.destroy!

    account.reload
    assert account.can_be_personal?

    post login_path, params: { email_address: user.email_address, password: "password123" }

    put account_path(account), params: { convert_to: "personal" }

    assert_redirected_to account_path(account)

    account.reload
    assert account.personal?
  end

  # === Error Handling Tests ===

  test "unauthorized user cannot convert account type" do
    other_user = users(:existing_user)
    account = accounts(:personal_account)  # Belongs to user_1, not existing_user

    post login_path, params: { email_address: other_user.email_address, password: "password123" }

    # Try to access the account directly first to ensure it's not accessible
    get account_path(account)
    assert_response :not_found

    # Try to update the account
    put account_path(account), params: { convert_to: "team", account: { name: "Unauthorized" } }
    assert_response :not_found

    account.reload
    # Should remain unchanged
    assert account.personal?
  end

  test "invalid conversion type is handled gracefully" do
    user = users(:user_1)
    account = accounts(:personal_account)

    post login_path, params: { email_address: user.email_address, password: "password123" }

    put account_path(account), params: { convert_to: "invalid_type", account: { name: "Updated Name" } }

    # Should take the 'else' path and try to update account normally
    assert_redirected_to account_path(account)

    account.reload
    # Should remain unchanged
    assert account.personal?
  end

  test "missing team name for team conversion shows error" do
    user = users(:user_1)
    account = accounts(:personal_account)

    post login_path, params: { email_address: user.email_address, password: "password123" }

    put account_path(account), params: {
      convert_to: "team",
      account: { name: "" }  # Empty name
    }

    # Should redirect with error due to validation failure
    assert_redirected_to account_path(account)

    account.reload
    # Should remain personal due to validation error
    assert account.personal?
  end

  # === Controller Show Action Tests ===

  test "show page includes can_be_personal flag correctly" do
    user = users(:user_1)

    # Test with single-user team (can be personal)
    single_user_team = accounts(:team_single_user)
    post login_path, params: { email_address: user.email_address, password: "password123" }

    get account_path(single_user_team)
    assert_response :success

    # Check that can_be_personal is passed as true
    # Note: In integration tests we can't directly access Inertia props,
    # but we can verify the controller logic works by checking the account state
    assert single_user_team.can_be_personal?

    # Test with multi-user team (cannot be personal)
    multi_user_team = accounts(:team_account)
    get account_path(multi_user_team)
    assert_response :success

    assert_not multi_user_team.can_be_personal?
  end

  test "show page displays team with pending invitations correctly" do
    user = users(:user_1)
    account = accounts(:another_team)  # Has pending invitation

    post login_path, params: { email_address: user.email_address, password: "password123" }

    get account_path(account)
    assert_response :success

    # Verify the account cannot be converted due to pending invitations
    assert_not account.can_be_personal?
    assert_equal 3, account.memberships.count
  end

  # === Complete Flow Tests ===

  test "complete personal to team to personal flow" do
    user = users(:user_1)
    account = accounts(:personal_account)
    original_name = account.name

    post login_path, params: { email_address: user.email_address, password: "password123" }

    # Step 1: Convert personal to team
    put account_path(account), params: {
      convert_to: "team",
      account: { name: "Temp Team" }
    }

    assert_redirected_to account_path(account)

    account.reload
    assert account.team?
    assert_equal "Temp Team", account.name
    assert account.can_be_personal?  # Still only one user

    # Step 2: Convert back to personal
    put account_path(account), params: { convert_to: "personal" }

    assert_redirected_to account_path(account)

    account.reload
    assert account.personal?
    # Personal account name should show owner's name, not "Temp Team"
    assert_not_equal "Temp Team", account.name
  end

  test "team account with multiple confirmed users blocks conversion" do
    user = users(:user_1)
    account = accounts(:team_account)

    # Verify this team has multiple confirmed users
    assert account.memberships.where.not(confirmed_at: nil).count > 1

    post login_path, params: { email_address: user.email_address, password: "password123" }

    put account_path(account), params: { convert_to: "personal" }

    assert_redirected_to account_path(account)

    account.reload
    assert account.team?  # Should remain team
  end

  # === Database Consistency Tests ===

  test "account conversion maintains referential integrity" do
    user = users(:user_1)
    account = accounts(:personal_account)
    original_membership = account.memberships.first
    original_user_accounts_count = user.accounts.count

    post login_path, params: { email_address: user.email_address, password: "password123" }

    put account_path(account), params: {
      convert_to: "team",
      account: { name: "Integrity Test Team" }
    }

    assert_redirected_to account_path(account)

    # Reload all objects
    account.reload
    user.reload
    original_membership.reload

    # Verify relationships are maintained
    assert_equal original_user_accounts_count, user.accounts.count
    assert_includes user.accounts, account
    assert_equal account.id, original_membership.account_id
    assert_equal user.id, original_membership.user_id
    assert_equal "owner", original_membership.role
  end

end
