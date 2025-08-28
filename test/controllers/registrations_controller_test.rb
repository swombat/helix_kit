require "test_helper"

class RegistrationsControllerTest < ActionDispatch::IntegrationTest

  test "should get signup page when not authenticated" do
    get signup_path
    assert_response :success
    assert_equal "registrations/signup", inertia_component
  end

  test "should redirect to root when accessing signup while authenticated" do
    user = users(:user_1)
    post login_path, params: { email_address: user.email_address, password: "password" }

    get signup_path
    assert_redirected_to root_path
    assert_equal "You are already signed in.", flash[:alert]
  end

  test "should create new user with valid params" do
    assert_difference("User.count", 1) do
      post signup_path, params: {
        email_address: "newuser@example.com",
        password: "password123",
        password_confirmation: "password123"
      }
    end

    assert_redirected_to root_path
    assert_equal "Successfully signed up!", flash[:notice]

    # Verify the user is logged in
    get root_path
    assert_response :success
  end

  test "should not create user with invalid email" do
    assert_no_difference("User.count") do
      post signup_path, params: {
        email_address: "invalid-email",
        password: "password123",
        password_confirmation: "password123"
      }
    end

    assert_redirected_to signup_path
    follow_redirect!
    errors = inertia_shared_props["errors"]
    assert errors.present?
    assert errors["email_address"].present?
  end

  test "should not create user with mismatched passwords" do
    assert_no_difference("User.count") do
      post signup_path, params: {
        email_address: "newuser@example.com",
        password: "password123",
        password_confirmation: "different-password"
      }
    end

    assert_redirected_to signup_path
    follow_redirect!
    errors = inertia_shared_props["errors"]
    assert errors.present?
    assert errors["password_confirmation"].present?
  end

  test "should not create user with duplicate email" do
    existing_user = users(:user_1)

    assert_no_difference("User.count") do
      post signup_path, params: {
        email_address: existing_user.email_address,
        password: "password123",
        password_confirmation: "password123"
      }
    end

    assert_redirected_to signup_path
    follow_redirect!
    errors = inertia_shared_props["errors"]
    assert errors.present?
    assert errors["email_address"].present?
  end

  test "should not create user with blank password" do
    assert_no_difference("User.count") do
      post signup_path, params: {
        email_address: "newuser@example.com",
        password: "",
        password_confirmation: ""
      }
    end

    assert_redirected_to signup_path
    follow_redirect!
    errors = inertia_shared_props["errors"]
    assert errors.present?
    assert errors["password"].present?
  end

  test "should log in user after successful registration" do
    post signup_path, params: {
      email_address: "newuser@example.com",
      password: "password123",
      password_confirmation: "password123"
    }

    assert_redirected_to root_path

    # Logout to test if the account was created properly
    delete logout_path

    # Try logging in with the new credentials
    post login_path, params: {
      email_address: "newuser@example.com",
      password: "password123"
    }
    assert_redirected_to root_path
    assert_equal "You have been signed in.", flash[:notice]
  end

  test "registration returns proper inertia errors structure" do
    post signup_path, params: {
      email_address: "invalid",
      password: "short",
      password_confirmation: "different"
    }

    assert_redirected_to signup_path
    follow_redirect!

    assert inertia_props.key?("props")
    assert inertia_shared_props.key?("errors")
    assert inertia_shared_props["errors"].is_a?(Hash)
  end

end
