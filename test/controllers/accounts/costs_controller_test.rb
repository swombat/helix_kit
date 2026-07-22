require "test_helper"

class Accounts::CostsControllerTest < ActionDispatch::IntegrationTest

  setup do
    @user = users(:user_1)
    @account = accounts(:personal_account)
    Setting.instance.update!(allow_agents: true)
    sign_in(@user)
  end

  test "shows account costs to confirmed account members" do
    get account_costs_path(@account)

    assert_response :success
    assert_equal @account.to_param, inertia_shared_props.dig("account", "id")
    assert inertia_shared_props.key?("cost_report")
  end

  test "does not expose costs for another account" do
    get account_costs_path(accounts(:other))

    assert_response :not_found
  end

end
