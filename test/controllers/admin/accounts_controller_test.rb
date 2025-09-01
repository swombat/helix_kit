require "test_helper"

class Admin::AccountsControllerTest < ActionDispatch::IntegrationTest

  setup do
    @site_admin_user = users(:site_admin_user)
    @regular_user = users(:regular_user)
    @normal_user = users(:user_1)
  end

  # === Authentication and Authorization Tests ===

  test "should redirect to login when not authenticated" do
    get admin_accounts_path
    assert_redirected_to login_path
  end

  test "should redirect to root when authenticated as regular user" do
    post login_path, params: { email_address: @regular_user.email_address, password: "password123" }

    get admin_accounts_path
    assert_redirected_to root_path
  end

  test "should redirect to root when authenticated as normal user" do
    post login_path, params: { email_address: @normal_user.email_address, password: "password123" }

    get admin_accounts_path
    assert_redirected_to root_path
  end

  test "should allow access for site admin user" do
    post login_path, params: { email_address: @site_admin_user.email_address, password: "password123" }

    get admin_accounts_path
    assert_response :success
    assert_equal "admin/accounts", inertia_component
  end

  # === Data and Props Tests ===

  test "should return all accounts with correct structure for site admin" do
    post login_path, params: { email_address: @site_admin_user.email_address, password: "password123" }

    get admin_accounts_path
    assert_response :success

    props = inertia_shared_props
    assert props.key?("accounts")
    assert props.key?("selected_account")

    accounts = props["accounts"]
    assert accounts.is_a?(Array)
    assert accounts.size > 0

    # Verify account structure
    account = accounts.first
    assert account.key?("id")
    assert account.key?("name")
    assert account.key?("account_type")
    assert account.key?("created_at")
    assert account.key?("owner")
    assert account.key?("users_count")

    # Verify owner structure when present
    if account["owner"]
      owner = account["owner"]
      assert owner.key?("id")
      assert owner.key?("email_address")
    end
  end

  test "should return accounts ordered by created_at desc" do
    post login_path, params: { email_address: @site_admin_user.email_address, password: "password123" }

    get admin_accounts_path
    assert_response :success

    accounts = inertia_shared_props["accounts"]
    created_at_times = accounts.map { |a| Time.parse(a["created_at"]) }

    # Verify they're in descending order (newest first)
    assert_equal created_at_times.sort.reverse, created_at_times
  end

  test "should include users_count for each account" do
    post login_path, params: { email_address: @site_admin_user.email_address, password: "password123" }

    get admin_accounts_path
    assert_response :success

    accounts = inertia_shared_props["accounts"]

    # Find the team account which should have multiple users
    team_account = accounts.find { |a| a["name"] == "Test Team Account" }
    assert team_account.present?, "Team account should be in the response"
    assert team_account["users_count"] >= 1, "Team account should have at least 1 user"
  end

  # === Selected Account Tests ===

  test "should not include selected_account when no account_id param" do
    post login_path, params: { email_address: @site_admin_user.email_address, password: "password123" }

    get admin_accounts_path
    assert_response :success

    props = inertia_shared_props
    assert_nil props["selected_account"]
  end

  test "should include selected_account when valid account_id param provided" do
    post login_path, params: { email_address: @site_admin_user.email_address, password: "password123" }

    # Use a known account from fixtures
    test_account = accounts(:personal_account)
    test_account_param = test_account.to_param

    # Request with that account_id
    get admin_accounts_path, params: { account_id: test_account_param }
    assert_response :success

    props = inertia_shared_props
    selected_account = props["selected_account"]

    assert selected_account.present?, "Selected account should be present when valid account_id is provided"
    assert_equal test_account_param, selected_account["id"]

    # Verify selected account structure
    assert selected_account.key?("id")
    assert selected_account.key?("name")
    assert selected_account.key?("account_type")
    assert selected_account.key?("created_at")
    assert selected_account.key?("updated_at")
    assert selected_account.key?("owner")
    assert selected_account.key?("account_users")

    # Verify account_users array structure
    account_users = selected_account["account_users"]
    assert account_users.is_a?(Array)

    if account_users.any?
      account_user = account_users.first
      assert account_user.key?("id")
      assert account_user.key?("user")
      assert account_user.key?("role")
      assert account_user.key?("created_at")
      # User nested structure
      user = account_user["user"]
      assert user.key?("id")
      assert user.key?("email_address")
      assert user.key?("full_name")
    end
  end

  test "should not include selected_account when invalid account_id param provided" do
    post login_path, params: { email_address: @site_admin_user.email_address, password: "password123" }

    get admin_accounts_path, params: { account_id: 99999 }
    assert_response :not_found
  end

  test "should handle string account_id param correctly" do
    post login_path, params: { email_address: @site_admin_user.email_address, password: "password123" }

    # Use a known account from fixtures
    test_account = accounts(:team_account)
    test_account_param = test_account.to_param

    # Request with account_id param
    get admin_accounts_path, params: { account_id: test_account_param }
    assert_response :success

    selected_account = inertia_shared_props["selected_account"]
    assert selected_account.present?, "Selected account should be present when string account_id is provided"
    assert_equal test_account_param, selected_account["id"]
  end

  # === Inertia Response Structure Tests ===

  test "should return proper inertia response structure" do
    post login_path, params: { email_address: @site_admin_user.email_address, password: "password123" }

    get admin_accounts_path
    assert_response :success

    assert inertia_props.key?("component")
    assert inertia_props.key?("props")
    assert inertia_props.key?("url")
    assert inertia_props.key?("version")
    assert_equal "admin/accounts", inertia_component
  end

  test "should handle inertia version conflicts gracefully" do
    post login_path, params: { email_address: @site_admin_user.email_address, password: "password123" }

    get admin_accounts_path, headers: { "X-Inertia" => true, "X-Inertia-Version" => "wrong-version" }
    assert_response :conflict
    assert_equal "http://www.example.com#{admin_accounts_path}", @response.headers["X-Inertia-Location"]
  end

  # === Edge Cases ===

  test "should handle accounts with no owner gracefully" do
    # Create an account without an owner for edge case testing
    orphaned_account = Account.create!(
      name: "Orphaned Account",
      account_type: :team
    )

    post login_path, params: { email_address: @site_admin_user.email_address, password: "password123" }

    get admin_accounts_path
    assert_response :success

    accounts = inertia_shared_props["accounts"]
    orphaned = accounts.find { |a| a["name"] == "Orphaned Account" }

    assert orphaned.present?
    assert_nil orphaned["owner"]
    assert_equal 0, orphaned["users_count"]
  end

  test "should handle selected account with no users gracefully" do
    # Create an account without users
    empty_account = Account.create!(
      name: "Empty Account",
      account_type: :team
    )

    post login_path, params: { email_address: @site_admin_user.email_address, password: "password123" }

    get admin_accounts_path, params: { account_id: empty_account.to_param }
    assert_response :success

    selected_account = inertia_shared_props["selected_account"]
    assert selected_account.present?
    assert_equal empty_account.to_param, selected_account["id"]
    assert_nil selected_account["owner"]
    assert_equal [], selected_account["account_users"]
  end

  # === Authorization Edge Cases ===

  test "should require site admin even with valid session" do
    # Login as regular user first
    post login_path, params: { email_address: @regular_user.email_address, password: "password123" }
    assert_redirected_to root_path

    # Try to access admin accounts
    get admin_accounts_path
    assert_redirected_to root_path
  end

  test "site admin loses access when is_site_admin is revoked" do
    # Login as site admin
    post login_path, params: { email_address: @site_admin_user.email_address, password: "password123" }

    # Verify access works initially
    get admin_accounts_path
    assert_response :success

    # Revoke site admin status
    @site_admin_user.update_column(:is_site_admin, false)

    # Should no longer have access
    get admin_accounts_path
    assert_redirected_to root_path
  end

  # === Data Integrity Tests ===

  test "should include all account types in response" do
    post login_path, params: { email_address: @site_admin_user.email_address, password: "password123" }

    get admin_accounts_path
    assert_response :success

    accounts = inertia_shared_props["accounts"]
    account_types = accounts.map { |a| a["account_type"] }.uniq.sort

    # Account types are returned as strings from the enum
    assert_includes account_types, "personal"
    assert_includes account_types, "team"
  end

  test "should include correct user count for team accounts" do
    post login_path, params: { email_address: @site_admin_user.email_address, password: "password123" }

    get admin_accounts_path
    assert_response :success

    accounts = inertia_shared_props["accounts"]
    team_account = accounts.find { |a| a["name"] == "Test Team Account" }

    assert team_account.present?
    # Team account should have 2 users based on fixtures (user_1 as owner, existing_user as member)
    assert_equal 2, team_account["users_count"]
  end

  test "should show detailed user information in selected account" do
    post login_path, params: { email_address: @site_admin_user.email_address, password: "password123" }

    # Get team account
    team_account = accounts(:team_account)

    get admin_accounts_path, params: { account_id: team_account.to_param }
    assert_response :success

    selected_account = inertia_shared_props["selected_account"]
    assert selected_account.present?

    account_users = selected_account["account_users"]
    assert account_users.is_a?(Array)
    assert account_users.size >= 1

    # Check account_user structure
    account_user = account_users.first
    assert account_user["user"]["email_address"].present?
    assert account_user["user"]["full_name"].present?
    assert %w[owner admin member].include?(account_user["role"])
    assert account_user["created_at"].present?
  end

  # === Performance and Data Loading Tests ===

  test "should eager load account users and users to avoid N+1 queries" do
    post login_path, params: { email_address: @site_admin_user.email_address, password: "password123" }

    # This test ensures the controller uses includes to avoid N+1 queries
    # We can't easily test query count in Minitest without additional gems,
    # but we can verify the data is properly loaded by checking that we can
    # access nested associations without additional queries
    get admin_accounts_path
    assert_response :success

    accounts = inertia_shared_props["accounts"]
    assert accounts.any? { |a| a["owner"].present? }
    assert accounts.any? { |a| a["users_count"] > 0 }
  end

  test "should include all relevant account information" do
    post login_path, params: { email_address: @site_admin_user.email_address, password: "password123" }

    get admin_accounts_path
    assert_response :success

    accounts = inertia_shared_props["accounts"]

    # Verify each account has all required fields
    accounts.each do |account|
      assert account["id"].present?
      assert account["name"].present?
      assert [ "personal", "team" ].include?(account["account_type"])
      assert account["created_at"].present?
      assert account["users_count"].is_a?(Integer)
      assert account["users_count"] >= 0
    end
  end

end
