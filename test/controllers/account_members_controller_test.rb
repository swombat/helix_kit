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
    assert inertia_shared_props["members"].present?
    assert inertia_shared_props["can_manage"].present?
    assert inertia_shared_props["current_user_id"].present?
  end

  test "destroy removes member" do
    # Use existing fixture member that can be removed
    member = account_users(:team_member_user)

    assert_difference "@account.account_users.count", -1 do
      delete account_member_path(@account, member)
    end

    assert_redirected_to account_path(@account)
    assert_equal "Member removed successfully", flash[:notice]
  end

  test "destroy handles last owner error" do
    # Use team_single_user fixture which has only one owner
    single_account = accounts(:team_single_user)
    owner_membership = account_users(:team_single_user_member)

    # Give admin access to test the removal
    sign_in users(:user_1)  # This user owns team_single_user

    assert_no_difference "single_account.account_users.count" do
      delete account_member_path(single_account, owner_membership)
    end

    assert_redirected_to account_path(single_account)
    assert_match /Cannot remove the last owner/, flash[:alert]
  end

  test "requires account membership" do
    other_account = accounts(:other)

    get account_members_path(other_account)
    assert_response :not_found
  end

  test "member cannot access members page" do
    member = users(:member)
    sign_in member

    # Member should be able to view but not manage
    get account_members_path(@account)
    assert_response :success

    assert_not inertia_shared_props["can_manage"]
  end

end
