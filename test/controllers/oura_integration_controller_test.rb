require "test_helper"

class OuraIntegrationControllerTest < ActionDispatch::IntegrationTest

  setup do
    @user = users(:confirmed_user)
    sign_in(@user)
  end

  test "show renders integration page" do
    get oura_integration_path
    assert_response :success
  end

  test "create stores state in session and redirects to Oura" do
    post oura_integration_path

    assert_response :redirect
    assert_includes response.location, "cloud.ouraring.com/oauth/authorize"
  end

  test "callback with error redirects with alert" do
    @user.create_oura_integration!

    get callback_oura_integration_path(error: "access_denied")

    assert_redirected_to oura_integration_path
  end

  test "destroy disconnects integration" do
    integration = @user.create_oura_integration!(
      access_token: "token",
      token_expires_at: 1.day.from_now
    )

    delete oura_integration_path

    assert_redirected_to oura_integration_path
    integration.reload
    assert_nil integration.access_token
  end

  test "update changes enabled setting" do
    integration = @user.create_oura_integration!(enabled: true)

    patch oura_integration_path, params: { oura_integration: { enabled: false } }

    assert_redirected_to oura_integration_path
    assert_not integration.reload.enabled?
  end

  test "destroy without integration redirects gracefully" do
    delete oura_integration_path
    assert_redirected_to oura_integration_path
  end

  test "update without integration redirects" do
    patch oura_integration_path, params: { oura_integration: { enabled: false } }
    assert_redirected_to oura_integration_path
  end

  test "sync enqueues job for connected integration" do
    @user.create_oura_integration!(
      access_token: "token",
      token_expires_at: 1.day.from_now
    )

    assert_enqueued_with(job: SyncOuraDataJob) do
      post sync_oura_integration_path
    end

    assert_redirected_to oura_integration_path
  end

  test "sync without connection redirects with alert" do
    @user.create_oura_integration!

    post sync_oura_integration_path

    assert_redirected_to oura_integration_path
  end

end
