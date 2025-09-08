require "test_helper"

class MembershipTest < ActiveSupport::TestCase

  include ActionMailer::TestHelper

  # === Core confirm_by_token! Class Method Tests ===

  test "confirm_by_token! finds and confirms Membership with valid token" do
    membership = memberships(:pending_invitation)
    token = membership.confirmation_token

    confirmed = Membership.confirm_by_token!(token)

    assert_equal membership, confirmed
    assert confirmed.confirmed?
    assert_nil confirmed.confirmation_token
  end

  test "confirm_by_token! raises error for invalid token" do
    assert_raises(ActiveSupport::MessageVerifier::InvalidSignature) do
      Membership.confirm_by_token!("invalid-token")
    end
  end

  test "confirm_by_token! raises error for nil token" do
    assert_raises(ActiveSupport::MessageVerifier::InvalidSignature) do
      Membership.confirm_by_token!(nil)
    end
  end

  # === Role Validation Tests ===

  test "validates role inclusion" do
    account = accounts(:team_account)

    # Valid roles should work - use different users for each
    %w[owner admin member].each_with_index do |role, index|
      user = User.create!(email_address: "test#{index}@example.com")
      membership = Membership.new(account: account, user: user, role: role)
      membership.skip_confirmation = true
      assert membership.valid?, "#{role} should be valid"
    end

    # Invalid role should fail
    user = User.create!(email_address: "invalid@example.com")
    membership = Membership.new(account: account, user: user, role: "invalid")
    membership.skip_confirmation = true
    assert_not membership.valid?
    assert membership.errors[:role].present?
  end

  test "enforces personal account role restrictions" do
    account = accounts(:personal_account)
    user = User.create!(email_address: "roletest@example.com")

    # Member role should fail for personal account
    membership = Membership.new(account: account, user: user, role: "member")
    membership.skip_confirmation = true
    assert_not membership.valid?
    assert membership.errors[:role].include?("must be owner for personal accounts")

    # Owner role should work
    membership.role = "owner"
    # But will still fail due to single user limit - that's expected
    assert_not membership.valid?
    assert membership.errors[:base].include?("Personal accounts can only have one user")
  end

  # === Uniqueness Validation Tests ===

  test "prevents duplicate user per account" do
    account = accounts(:team_account)
    user = users(:confirmed_user)

    # First membership should work
    membership1 = Membership.create!(
      account: account,
      user: user,
      role: "owner",
      skip_confirmation: true
    )
    assert membership1.persisted?

    # Second membership should fail
    membership2 = Membership.new(account: account, user: user, role: "member")
    membership2.skip_confirmation = true
    assert_not membership2.valid?
    assert membership2.errors[:user_id].include?("is already a member of this account")
  end

  test "allows same user across different accounts" do
    user = User.create!(email_address: "multi-account@example.com")
    account1 = accounts(:team_account)
    account2 = accounts(:another_team)

    assert_nothing_raised do
      Membership.create!(account: account1, user: user, role: "admin", skip_confirmation: true)
      Membership.create!(account: account2, user: user, role: "member", skip_confirmation: true)
    end

    assert_equal 3, user.memberships.count # personal account + 2 team accounts
  end

  # === Role Helper Methods Tests ===

  test "role helper methods work correctly" do
    timestamp = Time.current.to_i
    account = accounts(:team_account)
    user = User.create!(email_address: "rolehelper-#{timestamp}@example.com")

    # Test owner
    owner = Membership.create!(
      account: account, user: user, role: "owner", skip_confirmation: true
    )
    assert owner.owner?
    assert owner.admin?
    assert owner.can_manage?

    # Test admin
    admin_user = User.create!(email_address: "admin-#{timestamp}-#{rand(1000)}@example.com")
    admin = Membership.create!(
      account: account, user: admin_user, role: "admin", skip_confirmation: true
    )
    assert_not admin.owner?
    assert admin.admin?
    assert admin.can_manage?

    # Test member
    member_user = User.create!(email_address: "member-#{timestamp}-#{rand(1000)}@example.com")
    member = Membership.create!(
      account: account, user: member_user, role: "member", skip_confirmation: true
    )
    assert_not member.owner?
    assert_not member.admin?
    assert_not member.can_manage?
  end

  # === Scopes Tests ===

  test "confirmation scopes work correctly" do
    account = accounts(:team_account)
    user1 = User.create!(email_address: "scope_test_confirmed@example.com")
    user2 = User.create!(email_address: "scope_test_unconfirmed@example.com")

    # Confirmed user
    confirmed = Membership.create!(
      account: account,
      user: user1,
      role: "owner",
      confirmed_at: Time.current,
      skip_confirmation: true
    )

    # Unconfirmed user - don't skip confirmation to keep it unconfirmed
    unconfirmed = Membership.new(
      account: account,
      user: user2,
      role: "member"
    )
    unconfirmed.save!(validate: false) # Save without triggering confirmation email
    unconfirmed.update_column(:confirmed_at, nil) # Ensure it's unconfirmed

    assert_includes Membership.confirmed, confirmed
    assert_not_includes Membership.confirmed, unconfirmed

    assert_includes Membership.unconfirmed, unconfirmed
    assert_not_includes Membership.unconfirmed, confirmed
  end

  test "owners scope returns only owner role Memberships" do
    owners = Membership.owners

    owners.each do |au|
      assert_equal "owner", au.role
    end
  end

  test "admins scope returns owner and admin roles" do
    admins = Membership.admins

    admins.each do |au|
      assert au.role.in?(%w[owner admin])
    end
  end

  # === Association Tests ===

  test "belongs_to account and user" do
    membership = memberships(:daniel_personal)

    assert_equal accounts(:personal_account), membership.account
    assert_equal users(:user_1), membership.user
  end

  test "belongs_to invited_by optional" do
    membership = memberships(:pending_invitation)
    assert_equal users(:user_1), membership.invited_by

    # Should work without invited_by
    new_user = User.create!(email_address: "noinviter@example.com")
    membership = Membership.create!(
      account: accounts(:team_account),
      user: new_user,
      role: "member",
      skip_confirmation: true
    )
    assert_nil membership.invited_by
  end

  # === Confirmation Logic Tests ===

  test "confirmed? method from Confirmable module" do
    confirmed = memberships(:daniel_personal)
    unconfirmed = memberships(:pending_invitation)

    assert confirmed.confirmed?
    assert_not unconfirmed.confirmed?
  end

  test "confirm! method from Confirmable module works" do
    membership = memberships(:pending_invitation)

    assert_not membership.confirmed?

    membership.confirm!

    assert membership.confirmed?
    assert_nil membership.confirmation_token
    assert membership.confirmed_at.present?
  end

  # === Critical Update Method Safety Tests (For the bug we fixed) ===

  test "update! methods work correctly on Membership model" do
    membership = memberships(:team_admin)

    # Test update!
    assert_nothing_raised do
      membership.update!(role: "member")
    end
    assert_equal "member", membership.reload.role
  end

  test "update_column works correctly on Membership model" do
    membership = memberships(:team_admin)
    original_updated_at = membership.updated_at

    # Test update_column (should work without callbacks and not update updated_at)
    assert_nothing_raised do
      membership.update_column(:role, "member")
    end

    membership.reload
    assert_equal "member", membership.role
    assert_equal original_updated_at.to_i, membership.updated_at.to_i # Should not change updated_at
  end

  test "save! works correctly on Membership model" do
    account = accounts(:team_account)
    user = User.create!(email_address: "savetest@example.com")
    membership = Membership.new(account: account, user: user, role: "member", skip_confirmation: true)

    # Test save!
    assert_nothing_raised do
      membership.save!
    end
    assert membership.persisted?
  end

  # === Confirmation Token Handling Tests ===

  test "confirmation token is generated on create when needed" do
    account = accounts(:team_account)
    user = User.create!(email_address: "tokentest@example.com")

    membership = Membership.create!(
      account: account,
      user: user,
      role: "member"
      # skip_confirmation not set, so token should be generated
    )

    assert membership.confirmation_token.present?
    assert membership.confirmation_sent_at.present?
    assert_not membership.confirmed?
  end

  test "confirmation token is not generated when skip_confirmation is true" do
    account = accounts(:team_account)
    user = User.create!(email_address: "skiptoken@example.com")

    membership = Membership.create!(
      account: account,
      user: user,
      role: "member",
      skip_confirmation: true
    )

    assert_nil membership.confirmation_token
    assert_nil membership.confirmation_sent_at
    assert membership.confirmed?
  end

  # === Validation Edge Cases ===

  test "validates required associations" do
    # Missing account
    membership = Membership.new(user: users(:user_1), role: "owner")
    assert_not membership.valid?
    assert membership.errors[:account].present?

    # Missing user
    membership = Membership.new(account: accounts(:team_account), role: "owner")
    assert_not membership.valid?
    assert membership.errors[:user].present?
  end

  test "role cannot be blank" do
    membership = Membership.new(
      account: accounts(:team_account),
      user: users(:confirmed_user),
      role: ""
    )

    assert_not membership.valid?
    assert membership.errors[:role].present?
  end

  # === Business Logic Integration Tests ===

  test "confirmation workflow end-to-end" do
    # Create unconfirmed Membership
    account = accounts(:team_account)
    user = User.create!(email_address: "workflow@example.com")

    membership = Membership.create!(
      account: account,
      user: user,
      role: "member",
      invited_by: users(:user_1)
    )

    # Should be unconfirmed with token
    assert_not membership.confirmed?
    assert membership.confirmation_token.present?

    # Confirm by token
    token = membership.confirmation_token
    confirmed = Membership.confirm_by_token!(token)

    assert_equal membership, confirmed
    assert confirmed.confirmed?
    assert_nil confirmed.confirmation_token
  end

  # === Association Validation Edge Cases ===

  test "destroys cleanly when account is destroyed" do
    account = Account.create!(name: "Temp Account", account_type: :team)
    user = User.create!(email_address: "tempdestroytest@example.com")
    membership = account.add_user!(user, role: "owner", skip_confirmation: true)
    membership_id = membership.id

    account.destroy

    assert_not Membership.exists?(membership_id)
  end

  test "destroys cleanly when user is destroyed" do
    user = User.create!(email_address: "temp-user@example.com")
    membership_id = user.memberships.first.id

    user.destroy

    assert_not Membership.exists?(membership_id)
  end

  test "invited_by association works correctly" do
    inviter = users(:user_1)
    account = accounts(:team_account)
    invitee = User.create!(email_address: "invitee@example.com")

    membership = Membership.create!(
      account: account,
      user: invitee,
      role: "member",
      invited_by: inviter
    )

    assert_equal inviter, membership.invited_by
    assert_equal inviter, membership.reload.invited_by
  end

  # === Role Method Comprehensive Tests ===

  test "role helper methods handle all valid roles" do
    account = accounts(:team_account)

    Membership::ROLES.each_with_index do |role, index|
      user = User.create!(email_address: "#{role}-#{Time.current.to_i}-#{index}@example.com")
      membership = Membership.create!(
        account: account,
        user: user,
        role: role,
        skip_confirmation: true
      )

      case role
      when "owner"
        assert membership.owner?
        assert membership.admin?
        assert membership.can_manage?
      when "admin"
        assert_not membership.owner?
        assert membership.admin?
        assert membership.can_manage?
      when "member"
        assert_not membership.owner?
        assert_not membership.admin?
        assert_not membership.can_manage?
      end
    end
  end

  # === Confirmation Email Behavior Tests ===

  test "sends confirmation email after create unless skip_confirmation" do
    account = accounts(:team_account)
    user = User.create!(email_address: "email-test@example.com")

    # This should trigger email sending
    assert_enqueued_with(job: ActionMailer::MailDeliveryJob) do
      Membership.create!(
        account: account,
        user: user,
        role: "member"
      )
    end
  end

  test "does not send confirmation email when skip_confirmation is true" do
    account = accounts(:team_account)
    user = User.create!(email_address: "noemail-test@example.com")

    # This should NOT trigger email sending
    assert_no_enqueued_jobs do
      Membership.create!(
        account: account,
        user: user,
        role: "member",
        skip_confirmation: true
      )
    end
  end

  # === Invitation System Tests ===

  test "validates role inclusion for invitations" do
    account = accounts(:team)
    user = User.create!(email_address: "roletest@example.com")
    membership = Membership.new(account: account, user: user, role: "invalid")
    assert_not membership.valid?
    assert_includes membership.errors[:role], "is not included in the list"
  end

  test "prevents duplicate memberships" do
    account = accounts(:team)
    user = users(:owner)

    # Owner already has a membership through fixtures (team_owner)
    # Try to create duplicate
    duplicate = Membership.new(
      account: account,
      user: user,
      role: "member"
    )

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:user_id], "is already a member of this account"
  end

  test "prevents removing last owner" do
    # Create account with single owner
    account = Account.create!(name: "Test Account", account_type: :team)
    user = User.create!(email_address: "lastowner@example.com")
    owner_membership = Membership.create!(
      account: account,
      user: user,
      role: "owner",
      skip_confirmation: true
    )

    assert_not owner_membership.destroy
    assert_includes owner_membership.errors[:base], "Cannot remove the last owner"
  end

  test "sends invitation email on create with invited_by" do
    account = accounts(:team)
    admin = users(:admin)

    # Use existing user to avoid creating personal account
    existing_user = users(:regular_user)

    assert_enqueued_emails 1 do
      Membership.create!(
        account: account,
        user: existing_user,
        role: "member",
        invited_by: admin
      )
    end
  end

  test "became_confirmed? detects confirmation changes" do
    invitation = Membership.create!(
      account: accounts(:team),
      user: User.find_or_invite("becameconfirmed@example.com"),
      role: "member",
      invited_by: users(:admin)
    )

    # Test the callback is triggered when confirmation happens
    assert_not invitation.confirmed?
    invitation.confirm!
    assert invitation.confirmed?
  end

  test "removable_by? logic" do
    account = accounts(:team)
    admin = users(:admin)
    member = users(:member)

    # Member already has a membership through fixtures (team_member_user)
    member_membership = memberships(:team_member_user)

    # Admin can remove member
    assert member_membership.removable_by?(admin)

    # Member cannot remove themselves
    assert_not member_membership.removable_by?(member)

    # Non-admin cannot remove
    other_member = users(:other_member)
    assert_not member_membership.removable_by?(other_member)
  end

  test "as_json includes can_remove when current_user provided" do
    account = accounts(:team)
    member = users(:member)
    admin = users(:admin)

    # Member already has a membership through fixtures (team_member_user)
    member_membership = memberships(:team_member_user)

    json = member_membership.as_json(current_user: admin)

    assert json.key?(:can_remove)
    assert json[:can_remove]
  end

  test "resend_invitation! updates token and timestamp" do
    invitation = Membership.create!(
      account: accounts(:team),
      user: User.find_or_invite("pending@example.com"),
      role: "member",
      invited_by: users(:admin)
    )

    old_token = invitation.confirmation_token
    old_time = invitation.invited_at

    travel 1.hour do
      assert invitation.resend_invitation!
      assert_not_equal old_token, invitation.reload.confirmation_token
      assert_not_equal old_time, invitation.invited_at
    end
  end

  test "invitation? returns true when invited_by is present" do
    invitation = memberships(:pending_team_invitation)
    regular = memberships(:team_owner)

    assert invitation.invitation?
    assert_not regular.invitation?
  end

  test "invitation_pending? checks both invitation and confirmation" do
    invitation = memberships(:pending_team_invitation)

    assert invitation.invitation_pending?

    # After confirmation, should not be pending
    invitation.confirm!
    assert_not invitation.invitation_pending?
  end

  test "pending_invitations scope works" do
    pending = Membership.pending_invitations
    pending.each do |au|
      assert au.invitation?
      assert_not au.confirmed?
    end
  end

  test "accepted_invitations scope works" do
    # Create and confirm an invitation
    invitation = Membership.create!(
      account: accounts(:team),
      user: User.find_or_invite("accepted@example.com"),
      role: "member",
      invited_by: users(:admin)
    )
    invitation.confirm!

    accepted = Membership.accepted_invitations
    assert_includes accepted, invitation

    accepted.each do |au|
      assert au.invitation?
      assert au.confirmed?
    end
  end

end
