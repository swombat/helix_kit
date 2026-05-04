require "test_helper"

class ApplicationGatewayTest < ActiveSupport::TestCase

  setup do
    @user = users(:confirmed_user)
    @api_key = ApiKey.generate_for(@user, name: "MCP test")
  end

  teardown do
    ActionMCP::Current.reset
  end

  test "rejects missing bearer token" do
    error = assert_raises(ActionMCP::UnauthorizedError) do
      ApplicationGateway.new(request).call
    end

    assert_equal "Missing bearer token", error.message
  end

  test "rejects invalid bearer token" do
    error = assert_raises(ActionMCP::UnauthorizedError) do
      ApplicationGateway.new(request("HTTP_AUTHORIZATION" => "Bearer nope")).call
    end

    assert_equal "Invalid API key", error.message
  end

  test "accepts valid bearer token and stores user context" do
    gateway = ApplicationGateway.new(request("HTTP_AUTHORIZATION" => "Bearer #{@api_key.raw_token}")).call
    session = ActionMCP::Session.new

    gateway.configure_session(session)

    assert_equal @user, gateway.user
    assert_equal @user, ActionMCP::Current.user
    assert_equal({ "user_id" => @user.id }, session.session_data)
    assert @api_key.reload.last_used_at.present?
  end

  private

  def request(headers = {})
    ActionDispatch::Request.new(
      Rack::MockRequest.env_for("/", headers.merge("REMOTE_ADDR" => "127.0.0.1"))
    )
  end

end
