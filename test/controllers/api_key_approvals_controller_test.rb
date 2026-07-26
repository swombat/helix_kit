require "test_helper"

class ApiKeyApprovalsControllerTest < ActionDispatch::IntegrationTest

  setup do
    @user = users(:user_1)
    @account = accounts(:team_account)
    post login_path, params: {
      email_address: @user.email_address,
      password: "password123"
    }
    assert_redirected_to root_path

    @key_request = ApiKeyRequest.create_request(client_name: "Test Client")
  end

  test "show renders approval form for pending request" do
    get api_key_approval_path(@key_request.request_token)
    assert_response :success
    assert_equal "api_keys/approve", inertia_component
  end

  test "show redirects for expired request" do
    @key_request.update!(expires_at: 1.hour.ago)

    get api_key_approval_path(@key_request.request_token)
    assert_redirected_to account_api_keys_path(@user.default_account)
    assert_equal "This request has expired", flash[:alert]
  end

  test "show redirects for already approved request" do
    @key_request.approve!(user: @user, account: @account, key_name: "Test Key")

    get api_key_approval_path(@key_request.request_token)
    assert_redirected_to account_api_keys_path(@account)
    assert_equal "This request has already been processed", flash[:alert]
  end

  test "show redirects for invalid token" do
    get api_key_approval_path("invalid_token")
    assert_redirected_to account_api_keys_path(@user.default_account)
    assert_equal "Invalid request", flash[:alert]
  end

  test "create approves the request" do
    assert_difference "ApiKey.count", 1 do
      post api_key_approval_path(@key_request.request_token), params: { key_name: "My Key", account_id: @account.id }
    end

    assert_response :success
    assert_equal "api_keys/approved", inertia_component
    assert @key_request.reload.approved?
    assert_equal @account, @key_request.api_key.account
  end

  test "create rejects expired request" do
    @key_request.update!(expires_at: 1.hour.ago)

    assert_no_difference "ApiKey.count" do
      post api_key_approval_path(@key_request.request_token), params: { key_name: "My Key", account_id: @account.id }
    end

    assert_redirected_to account_api_keys_path(@account)
    assert_equal "This request is no longer valid", flash[:alert]
  end

  test "destroy denies the request" do
    delete api_key_approval_path(@key_request.request_token)

    assert_redirected_to account_api_keys_path(@user.default_account)
    assert_equal "Request denied", flash[:notice]
    assert @key_request.reload.denied?
  end

  test "requires authentication" do
    delete logout_path

    get api_key_approval_path(@key_request.request_token)
    assert_response :redirect
  end

end
