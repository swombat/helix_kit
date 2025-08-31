# test/integration/invitation_flow_test.rb
require "test_helper"

class InvitationFlowTest < ActionDispatch::IntegrationTest

  test "complete invitation flow" do
    admin = users(:admin)
    account = accounts(:team)

    # 1. Admin sends invitation
    sign_in admin

    # Two AccountUser records: personal account + team invitation
    assert_difference "AccountUser.count", 2 do
      post account_invitations_path(account), params: {
        email: "newuser@example.com",
        role: "member"
      }
    end

    invitation = AccountUser.last
    assert invitation.invitation?
    assert_equal admin, invitation.invited_by
    assert invitation.invitation_pending?

    # 2. User accepts invitation
    get email_confirmation_path(token: invitation.confirmation_token)

    invitation.reload
    assert invitation.confirmed?
    assert invitation.invitation_accepted_at.present?
    assert_not invitation.invitation_pending?

    # 3. User can now access the account
    user = invitation.user
    user.update!(password: "ValidPassword123", first_name: "New", last_name: "User")

    sign_in user
    get account_path(account)
    assert_response :success
  end

  test "admin can resend invitation" do
    admin = users(:admin)
    account = accounts(:team)

    sign_in admin

    # Create pending invitation
    post account_invitations_path(account), params: {
      email: "pending@example.com",
      role: "member"
    }

    invitation = AccountUser.last
    original_token = invitation.confirmation_token
    original_time = invitation.invited_at

    # Resend invitation
    travel 1.hour do
      assert_enqueued_emails 1 do
        post resend_account_invitation_path(account, invitation)
      end
    end

    invitation.reload
    assert_not_equal original_token, invitation.confirmation_token
    assert_not_equal original_time, invitation.invited_at
  end

  test "members cannot invite or remove other members" do
    member = users(:member)
    account = accounts(:team)

    sign_in member

    # Try to invite - should be denied
    post account_invitations_path(account), params: {
      email: "unauthorized@example.com",
      role: "member"
    }

    assert_redirected_to account_path(account)
    assert_match /don't have permission/, flash[:alert]
  end

  test "cannot remove last owner from account" do
    # Use existing fixtures
    account = accounts(:team_single_user)
    owner = users(:user_1)
    owner_membership = account_users(:team_single_user_member)

    sign_in owner

    # Try to remove the owner
    assert_no_difference "AccountUser.count" do
      delete account_member_path(account, owner_membership)
    end

    assert_redirected_to account_path(account)
    assert_match /Cannot remove the last owner/, flash[:alert]
  end

  test "personal accounts cannot send invitations" do
    owner = users(:owner)
    personal_account = accounts(:personal)

    sign_in owner

    post account_invitations_path(personal_account), params: {
      email: "shouldfail@example.com",
      role: "member"
    }

    # Should fail validation
    assert_redirected_to account_path(personal_account)
    assert_match /Personal accounts can only have one user/, flash[:alert]
  end

end
