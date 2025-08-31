# test/controllers/account_members_controller_test.rb
require "test_helper"

class AccountMembersControllerTest < ActionDispatch::IntegrationTest

  setup do
    @admin = users(:admin)
    @account = accounts(:team)
    sign_in @admin
  end

  test "index returns members with can_remove flag" do
    get account_members_path(@account)
    assert_response :success

    # Verify the response structure includes necessary props
    response_props = controller.instance_variable_get(:@_inertia_props)
    assert response_props[:members].present?
    assert response_props[:can_manage].present?
    assert response_props[:current_user_id].present?
  end

  test "destroy removes member" do
    # Create a member to remove
    member_user = User.create!(email_address: "removeme@example.com")
    member = AccountUser.create!(
      account: @account,
      user: member_user,
      role: "member",
      skip_confirmation: true
    )

    assert_difference "@account.account_users.count", -1 do
      delete account_member_path(@account, member)
    end

    assert_redirected_to account_members_path(@account)
    assert_equal "Member removed successfully", flash[:notice]
  end

  test "destroy handles last owner error" do
    # Create account with single owner
    single_account = Account.create!(name: "Single Owner Account", account_type: :team)
    owner = User.create!(email_address: "singleowner@example.com")
    owner_membership = AccountUser.create!(
      account: single_account,
      user: owner,
      role: "owner",
      skip_confirmation: true
    )

    # Admin needs access to the account
    AccountUser.create!(
      account: single_account,
      user: @admin,
      role: "admin",
      skip_confirmation: true
    )

    assert_no_difference "single_account.account_users.count" do
      delete account_member_path(single_account, owner_membership)
    end

    assert_redirected_to account_members_path(single_account)
    assert_match /Cannot remove the last owner/, flash[:alert]
  end

  test "requires account membership" do
    other_account = accounts(:other)

    assert_raises(ActiveRecord::RecordNotFound) do
      get account_members_path(other_account)
    end
  end

  test "member cannot access members page" do
    member = users(:member)
    sign_in member

    # Member should be able to view but not manage
    get account_members_path(@account)
    assert_response :success

    response_props = controller.instance_variable_get(:@_inertia_props)
    assert_not response_props[:can_manage]
  end

end
