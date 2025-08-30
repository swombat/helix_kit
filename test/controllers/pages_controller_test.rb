require "test_helper"

class PagesControllerTest < ActionDispatch::IntegrationTest

  test "should get home page without authentication" do
    get root_path
    assert_response :success
    assert_equal "home", inertia_component
  end

  test "should get home page with authentication" do
    user = users(:user_1)
    post login_path, params: { email_address: user.email_address, password: "password" }

    get root_path
    assert_response :success
    assert_equal "home", inertia_component
  end

  test "home page returns proper inertia response structure" do
    get root_path
    assert_response :success

    assert inertia_props.key?("component")
    assert inertia_props.key?("props")
    assert inertia_props.key?("url")
    assert inertia_props.key?("version")
  end

  test "should handle inertia version conflicts gracefully" do
    get root_path, headers: { "X-Inertia" => true, "X-Inertia-Version" => "wrong-version" }
    assert_response :conflict
    assert_equal "http://www.example.com#{root_path}", @response.headers["X-Inertia-Location"]
  end

end
