require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest

  setup do
    @user = users(:user_1)
  end

  test "should get login page when not authenticated" do
    get login_path
    assert_response :success
    assert_equal "sessions/login", inertia_component
  end

  test "should redirect to root when accessing login while authenticated" do
    post login_path, params: { email_address: @user.email_address, password: "password" }

    get login_path
    assert_redirected_to root_path
    assert_equal "You are already signed in.", flash[:notice]
  end

  test "should login with valid credentials" do
    post login_path, params: {
      email_address: @user.email_address,
      password: "password"
    }

    assert_redirected_to root_path
    assert_equal "You have been signed in.", flash[:notice]
  end

  test "should not login with invalid email" do
    post login_path, params: {
      email_address: "wrong@example.com",
      password: "password"
    }

    assert_redirected_to login_path
    assert_equal "Invalid email or password.", flash[:alert]

    follow_redirect!
    errors = inertia_shared_props["errors"]
    assert errors.present?
    assert errors["email_address"].present?
  end

  test "should not login with invalid password" do
    post login_path, params: {
      email_address: @user.email_address,
      password: "wrongpassword"
    }

    assert_redirected_to login_path
    assert_equal "Invalid email or password.", flash[:alert]

    follow_redirect!
    errors = inertia_shared_props["errors"]
    assert errors.present?
    assert errors["email_address"].present?
  end

  test "should not login with blank email" do
    post login_path, params: {
      email_address: "",
      password: "password"
    }

    assert_redirected_to login_path
    assert_equal "Invalid email or password.", flash[:alert]
  end

  test "should not login with blank password" do
    post login_path, params: {
      email_address: @user.email_address,
      password: ""
    }

    assert_redirected_to login_path
    assert_equal "Invalid email or password.", flash[:alert]
  end

  test "should logout successfully" do
    # First login
    post login_path, params: {
      email_address: @user.email_address,
      password: "password"
    }
    assert_redirected_to root_path

    # Then logout
    delete logout_path
    assert_redirected_to root_path
    assert_equal "You have been signed out.", flash[:notice]

    # Verify we're logged out by trying to access a protected resource
    # Since we don't have protected resources defined in the controllers we've seen,
    # we'll verify by trying to login again (which should work if we're logged out)
    get login_path
    assert_response :success
  end

  # Rate limiting test is complex to test in isolation
  # as it requires persistent state across requests

  test "login returns proper inertia response structure" do
    get login_path
    assert_response :success

    assert inertia_props.key?("component")
    assert inertia_props.key?("props")
    assert inertia_props.key?("url")
    assert inertia_props.key?("version")
    assert_equal "sessions/login", inertia_component
  end

  test "successful login creates a session" do
    assert_changes -> { Session.count }, 1 do
      post login_path, params: {
        email_address: @user.email_address,
        password: "password"
      }
    end
    assert_redirected_to root_path
  end

  test "logout destroys the session" do
    # Login first
    post login_path, params: {
      email_address: @user.email_address,
      password: "password"
    }

    # Then logout and verify session is destroyed
    assert_changes -> { Session.count }, -1 do
      delete logout_path
    end
    assert_redirected_to root_path
  end

  test "login errors are passed via inertia props" do
    post login_path, params: {
      email_address: "wrong@example.com",
      password: "wrongpassword"
    }

    assert_redirected_to login_path
    follow_redirect!

    assert inertia_shared_props["errors"].present?
    assert inertia_shared_props["errors"]["email_address"].include?("Invalid email or password.")
  end

end
