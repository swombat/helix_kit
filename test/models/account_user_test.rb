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
    user = User.create!(email_address: "multi-account@example.com")
    account1 = accounts(:team_account)
    account2 = accounts(:another_team)

    assert_nothing_raised do
      AccountUser.create!(account: account1, user: user, role: "admin", skip_confirmation: true)
      AccountUser.create!(account: account2, user: user, role: "member", skip_confirmation: true)
    end

    assert_equal 3, user.account_users.count # personal account + 2 team accounts
  end

  # === Role Helper Methods Tests ===

  test "role helper methods work correctly" do
    timestamp = Time.current.to_i
    account = accounts(:team_account)
    user = User.create!(email_address: "rolehelper-#{timestamp}@example.com")

    # Test owner
    owner = AccountUser.create!(
      account: account, user: user, role: "owner", skip_confirmation: true
    )
    assert owner.owner?
    assert owner.admin?
    assert owner.can_manage?

    # Test admin
    admin_user = User.create!(email_address: "admin-#{timestamp}-#{rand(1000)}@example.com")
    admin = AccountUser.create!(
      account: account, user: admin_user, role: "admin", skip_confirmation: true
    )
    assert_not admin.owner?
    assert admin.admin?
    assert admin.can_manage?

    # Test member
    member_user = User.create!(email_address: "member-#{timestamp}-#{rand(1000)}@example.com")
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
    user1 = User.create!(email_address: "scope_test_confirmed@example.com")
    user2 = User.create!(email_address: "scope_test_unconfirmed@example.com")

    # Confirmed user
    confirmed = AccountUser.create!(
      account: account,
      user: user1,
      role: "owner",
      confirmed_at: Time.current,
      skip_confirmation: true
    )

    # Unconfirmed user - don't skip confirmation to keep it unconfirmed
    unconfirmed = AccountUser.new(
      account: account,
      user: user2,
      role: "member"
    )
    unconfirmed.save!(validate: false) # Save without triggering confirmation email
    unconfirmed.update_column(:confirmed_at, nil) # Ensure it's unconfirmed

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

  # === Association Validation Edge Cases ===

  test "destroys cleanly when account is destroyed" do
    account = Account.create!(name: "Temp Account", account_type: :team)
    user = User.create!(email_address: "temp@example.com")
    account_user = account.add_user!(user, role: "owner", skip_confirmation: true)
    account_user_id = account_user.id

    account.destroy

    assert_not AccountUser.exists?(account_user_id)
  end

  test "destroys cleanly when user is destroyed" do
    user = User.create!(email_address: "temp-user@example.com")
    account_user_id = user.account_users.first.id

    user.destroy

    assert_not AccountUser.exists?(account_user_id)
  end

  test "invited_by association works correctly" do
    inviter = users(:user_1)
    account = accounts(:team_account)
    invitee = User.create!(email_address: "invitee@example.com")

    account_user = AccountUser.create!(
      account: account,
      user: invitee,
      role: "member",
      invited_by: inviter
    )

    assert_equal inviter, account_user.invited_by
    assert_equal inviter, account_user.reload.invited_by
  end

  # === Role Method Comprehensive Tests ===

  test "role helper methods handle all valid roles" do
    account = accounts(:team_account)

    AccountUser::ROLES.each_with_index do |role, index|
      user = User.create!(email_address: "#{role}-#{Time.current.to_i}-#{index}@example.com")
      account_user = AccountUser.create!(
        account: account,
        user: user,
        role: role,
        skip_confirmation: true
      )

      case role
      when "owner"
        assert account_user.owner?
        assert account_user.admin?
        assert account_user.can_manage?
      when "admin"
        assert_not account_user.owner?
        assert account_user.admin?
        assert account_user.can_manage?
      when "member"
        assert_not account_user.owner?
        assert_not account_user.admin?
        assert_not account_user.can_manage?
      end
    end
  end

  # === Confirmation Email Behavior Tests ===

  test "sends confirmation email after create unless skip_confirmation" do
    account = accounts(:team_account)
    user = User.create!(email_address: "email-test@example.com")

    # This should trigger email sending
    assert_enqueued_with(job: ActionMailer::MailDeliveryJob) do
      AccountUser.create!(
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
      AccountUser.create!(
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
    account_user = AccountUser.new(account: account, user: user, role: "invalid")
    assert_not account_user.valid?
    assert_includes account_user.errors[:role], "is not included in the list"
  end

  test "prevents duplicate memberships" do
    account = accounts(:team)
    user = users(:owner)

    # First create a membership
    AccountUser.create!(
      account: account,
      user: user,
      role: "owner",
      skip_confirmation: true
    )

    # Try to create duplicate
    duplicate = AccountUser.new(
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
    owner_membership = AccountUser.create!(
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

    assert_enqueued_emails 1 do
      AccountUser.create!(
        account: account,
        user: User.find_or_invite("new@example.com"),
        role: "member",
        invited_by: admin
      )
    end
  end

  test "became_confirmed? detects confirmation changes" do
    invitation = AccountUser.create!(
      account: accounts(:team),
      user: User.find_or_invite("test@example.com"),
      role: "member",
      invited_by: users(:admin)
    )

    invitation.confirmed_at = Time.current
    assert invitation.became_confirmed?
  end

  test "removable_by? logic" do
    account = accounts(:team)
    admin = users(:admin)
    member = users(:member)

    # Create member account user
    member_account_user = AccountUser.create!(
      account: account,
      user: member,
      role: "member",
      skip_confirmation: true
    )

    # Admin can remove member
    assert member_account_user.removable_by?(admin)

    # Member cannot remove themselves
    assert_not member_account_user.removable_by?(member)

    # Non-admin cannot remove
    other_member = users(:other_member)
    assert_not member_account_user.removable_by?(other_member)
  end

  test "as_json includes can_remove when current_user provided" do
    account = accounts(:team)
    member = users(:member)
    admin = users(:admin)

    member_account_user = AccountUser.create!(
      account: account,
      user: member,
      role: "member",
      skip_confirmation: true
    )

    json = member_account_user.as_json(current_user: admin)

    assert json.key?(:can_remove)
    assert json[:can_remove]
  end

  test "resend_invitation! updates token and timestamp" do
    invitation = AccountUser.create!(
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
    invitation = account_users(:pending_team_invitation)
    regular = account_users(:team_owner)

    assert invitation.invitation?
    assert_not regular.invitation?
  end

  test "invitation_pending? checks both invitation and confirmation" do
    invitation = account_users(:pending_team_invitation)

    assert invitation.invitation_pending?

    # After confirmation, should not be pending
    invitation.confirm!
    assert_not invitation.invitation_pending?
  end

  test "pending_invitations scope works" do
    pending = AccountUser.pending_invitations
    pending.each do |au|
      assert au.invitation?
      assert_not au.confirmed?
    end
  end

  test "accepted_invitations scope works" do
    # Create and confirm an invitation
    invitation = AccountUser.create!(
      account: accounts(:team),
      user: User.find_or_invite("accepted@example.com"),
      role: "member",
      invited_by: users(:admin)
    )
    invitation.confirm!

    accepted = AccountUser.accepted_invitations
    assert_includes accepted, invitation

    accepted.each do |au|
      assert au.invitation?
      assert au.confirmed?
    end
  end

end
