require "test_helper"

class ServiceAuthorizationsControllerTest < ActionDispatch::IntegrationTest

  setup do
    @user = users(:user_1)
    @account = accounts(:personal_account)
    sign_in @user
  end

  test "starts Dropbox authorization with PKCE and no confidential credentials" do
    assert_difference "ServiceAuthorizationAttempt.count", 1 do
      post account_service_authorizations_path(@account), params: {
        provider: "dropbox",
        management_scope: "personal",
        access_profile: "full_sharing"
      }
    end

    assert_response :redirect
    uri = URI(response.location)
    query = Rack::Utils.parse_query(uri.query)
    attempt = ServiceAuthorizationAttempt.order(:id).last

    assert_equal "www.dropbox.com", uri.host
    assert_equal "/oauth2/authorize", uri.path
    assert_equal "code", query.fetch("response_type")
    assert_equal "offline", query.fetch("token_access_type")
    assert_equal "S256", query.fetch("code_challenge_method")
    assert query.fetch("code_challenge").present?
    assert query.fetch("state").present?
    assert_equal attempt.requested_scopes.sort, query.fetch("scope").split.sort
    assert_equal ServiceAuthorizationAttempt.digest(query.fetch("state")), attempt.state_digest
    assert_equal service_authorization_callback_url, query.fetch("redirect_uri")
    assert_not query.key?("client_secret")
    assert_not query.key?("access_token")
  end

  test "callback rejects authorization state started by another signed-in user" do
    _attempt, state = ServiceAuthorizationAttempt.begin!(
      account: @account,
      user: users(:existing_user),
      provider: "dropbox",
      management_scope: "personal",
      access_profile: "read_only",
      return_path: account_personal_services_path(@account)
    )

    assert_no_difference "ServiceConnection.count" do
      get service_authorization_callback_path, params: { state: state, code: "provider-code" }
    end

    assert_redirected_to root_path
  end

end
