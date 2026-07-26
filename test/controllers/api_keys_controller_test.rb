require "test_helper"

class ApiKeysControllerTest < ActionDispatch::IntegrationTest

  setup do
    @user = users(:user_1)
    @account = accounts(:team_account)
    sign_in(@user)
  end

  test "legacy API keys URL redirects to account-scoped external access" do
    get api_keys_path

    assert_redirected_to account_api_keys_path(@user.default_account)
  end

  test "index lists only the current user's keys for the selected account" do
    included = ApiKey.generate_for(@user, account: @account, name: "Included")
    ApiKey.generate_for(@user, account: accounts(:personal_account), name: "Other Account")

    get account_api_keys_path(@account)

    assert_response :success
    assert_equal "api_keys/index", inertia_component
    assert_equal [ included.id ], inertia_shared_props.fetch("api_keys").map { |key| key.fetch("id") }
  end

  test "create scopes the external access key to the selected account" do
    assert_difference "ApiKey.count", 1 do
      post account_api_keys_path(@account), params: { name: "Claude Code" }
    end

    assert_response :success
    key = ApiKey.order(:created_at).last
    assert_equal @account, key.account
    assert_equal @user, key.user
  end

  test "destroy cannot revoke a key from another account" do
    key = ApiKey.generate_for(@user, account: accounts(:personal_account), name: "Other Account")

    delete account_api_key_path(@account, key)

    assert_response :not_found
    assert key.reload.persisted?
  end

end
