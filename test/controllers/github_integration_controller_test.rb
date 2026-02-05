require "test_helper"

class GithubIntegrationControllerTest < ActionDispatch::IntegrationTest

  setup do
    @user = users(:confirmed_user)
    @account = accounts(:confirmed_user_account)
    sign_in(@user)
  end

  test "show renders integration page" do
    get github_integration_path
    assert_response :success
  end

  test "show builds integration if none exists" do
    get github_integration_path
    assert_response :success
    assert_equal "settings/github_integration", inertia_component
  end

  test "show renders existing integration" do
    @account.create_github_integration!(
      access_token: "token",
      github_username: "testuser",
      repository_full_name: "org/repo"
    )

    get github_integration_path
    assert_response :success
    props = inertia_shared_props["integration"]
    assert props["connected"]
    assert_equal "testuser", props["github_username"]
    assert_equal "org/repo", props["repository_full_name"]
  end

  test "create stores state in session and redirects to GitHub" do
    original_dig = Rails.application.credentials.method(:dig)
    Rails.application.credentials.define_singleton_method(:dig) do |*keys|
      if keys.first == :github
        { client_id: "test_client_id", client_secret: "test_client_secret" }.dig(*keys[1..])
      else
        original_dig.call(*keys)
      end
    end

    post github_integration_path

    assert_response :redirect
    assert_includes response.location, "github.com/login/oauth/authorize"
  ensure
    Rails.application.credentials.define_singleton_method(:dig, original_dig)
  end

  test "callback with error redirects with alert" do
    @account.create_github_integration!

    get callback_github_integration_path(error: "access_denied")

    assert_redirected_to github_integration_path
  end

  test "callback with invalid state redirects with alert" do
    @account.create_github_integration!

    get callback_github_integration_path(state: "invalid", code: "abc123")

    assert_redirected_to github_integration_path
  end

  test "callback without integration redirects with alert" do
    # Set up valid session state but no integration
    state = SecureRandom.hex(32)

    # We need to set session state, so we use a trick: make a request first to get a session
    get github_integration_path

    get callback_github_integration_path(state: state, code: "abc123")

    assert_redirected_to github_integration_path
  end

  test "select_repo without connection redirects" do
    @account.create_github_integration!

    get select_repo_github_integration_path

    assert_redirected_to github_integration_path
  end

  test "select_repo with connection renders repo picker" do
    @account.create_github_integration!(
      access_token: "token",
      github_username: "testuser"
    )

    mock_body = [
      { "full_name" => "org/repo1", "private" => false },
      { "full_name" => "org/repo2", "private" => true }
    ].to_json
    mock_response = Net::HTTPSuccess.new("1.1", "200", "OK")
    mock_response.instance_variable_set(:@body, mock_body)
    mock_response.instance_variable_set(:@read, true)

    mock_http = Minitest::Mock.new
    mock_http.expect(:request, mock_response, [Net::HTTP::Get])

    Net::HTTP.stub(:start, ->(hostname, port, **opts, &block) { block.call(mock_http) }) do
      get select_repo_github_integration_path
      assert_response :success
      assert_equal "settings/github_select_repo", inertia_component
    end
  end

  test "save_repo without connection redirects" do
    @account.create_github_integration!

    post save_repo_github_integration_path, params: { repository_full_name: "org/repo" }

    assert_redirected_to github_integration_path
  end

  test "save_repo saves chosen repo and enqueues job" do
    integration = @account.create_github_integration!(
      access_token: "token",
      github_username: "testuser"
    )

    assert_enqueued_with(job: SyncGithubCommitsJob) do
      post save_repo_github_integration_path, params: { repository_full_name: "org/repo" }
    end

    assert_redirected_to github_integration_path
    assert_equal "org/repo", integration.reload.repository_full_name
  end

  test "update changes enabled setting" do
    integration = @account.create_github_integration!(enabled: true)

    patch github_integration_path, params: { github_integration: { enabled: false } }

    assert_redirected_to github_integration_path
    assert_not integration.reload.enabled?
  end

  test "update without integration redirects with alert" do
    patch github_integration_path, params: { github_integration: { enabled: false } }
    assert_redirected_to github_integration_path
  end

  test "destroy disconnects integration" do
    integration = @account.create_github_integration!(
      access_token: "token",
      github_username: "testuser",
      repository_full_name: "org/repo"
    )

    delete github_integration_path

    assert_redirected_to github_integration_path
    integration.reload
    assert_nil integration.access_token
    assert_nil integration.repository_full_name
    assert_equal "testuser", integration.github_username
  end

  test "destroy without integration redirects gracefully" do
    delete github_integration_path
    assert_redirected_to github_integration_path
  end

  test "sync enqueues job for connected integration with repo" do
    @account.create_github_integration!(
      access_token: "token",
      github_username: "testuser",
      repository_full_name: "org/repo"
    )

    assert_enqueued_with(job: SyncGithubCommitsJob) do
      post sync_github_integration_path
    end

    assert_redirected_to github_integration_path
  end

  test "sync without repo redirects with alert" do
    @account.create_github_integration!(
      access_token: "token",
      github_username: "testuser"
    )

    post sync_github_integration_path

    assert_redirected_to github_integration_path
  end

  test "sync without connection redirects with alert" do
    @account.create_github_integration!

    post sync_github_integration_path

    assert_redirected_to github_integration_path
  end

end
