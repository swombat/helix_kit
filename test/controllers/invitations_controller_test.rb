# test/controllers/invitations_controller_test.rb
require "test_helper"

class InvitationsControllerTest < ActionDispatch::IntegrationTest

  setup do
    @admin = users(:admin)
    @account = accounts(:team)
    sign_in @admin
  end

  test "create sends invitation" do
    # Two AccountUser records: one for personal account, one for team invitation
    assert_difference "AccountUser.count", 2 do
      # Two emails: one for the new user's personal account confirmation,
      # and one for the team invitation
      assert_enqueued_emails 2 do
        post account_invitations_path(@account), params: {
          email: "newmember@example.com",
          role: "member"
        }
      end
    end

    assert_redirected_to account_path(@account)
    assert_equal "Invitation sent to newmember@example.com", flash[:notice]
  end

  test "create handles validation errors" do
    # Try to invite existing member
    existing = @account.users.first

    assert_no_difference "AccountUser.count" do
      post account_invitations_path(@account), params: {
        email: existing.email_address,
        role: "member"
      }
    end

    assert_redirected_to account_path(@account)
    assert_match /already a member/, flash[:alert]
  end

  test "resend updates invitation" do
    # Use existing pending invitation fixture
    invitation = account_users(:pending_team_invitation)

    assert_enqueued_emails 1 do
      post resend_account_invitation_path(@account, invitation)
    end

    assert_redirected_to account_path(@account)
    assert_equal "Invitation resent", flash[:notice]
  end

  test "members cannot invite" do
    member = users(:member)
    sign_in member

    post account_invitations_path(@account), params: {
      email: "test@example.com",
      role: "member"
    }

    assert_redirected_to account_path(@account)
    assert_match /don't have permission/, flash[:alert]
  end

  test "requires account membership" do
    other_account = accounts(:other)
    # Admin doesn't have access to this other account

    post account_invitations_path(other_account), params: {
      email: "test@example.com",
      role: "member"
    }

    assert_response :not_found
  end

  test "personal accounts cannot invite" do
    personal_account = accounts(:personal)
    # Use a user who has access to this personal account
    owner_user = personal_account.users.first
    sign_in owner_user

    post account_invitations_path(personal_account), params: {
      email: "test@example.com",
      role: "member"
    }

    assert_redirected_to account_path(personal_account)
    # Check for the actual validation error from personal account rules
    assert_match /Personal accounts cannot invite members|must be owner for personal accounts/, flash[:alert]
  end

end
