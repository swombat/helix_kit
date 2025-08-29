require "test_helper"

class SignupConfirmationTest < ActionDispatch::IntegrationTest

  test "signup flow with email confirmation" do
    # Visit signup page
    get signup_path
    assert_response :success

    # Submit email
    assert_difference "User.count", 1 do
      post signup_path, params: { email_address: "test@example.com" }
    end
    assert_redirected_to check_email_path

    # Check user was created without password
    user = User.last
    assert_equal "test@example.com", user.email_address
    assert_nil user.password_digest
    assert_not user.confirmed?
    assert_not_nil user.confirmation_token
    assert_not_nil user.confirmation_sent_at

    # Visit confirmation link
    get email_confirmation_path(token: user.confirmation_token)
    assert_redirected_to set_password_path
    follow_redirect!
    assert_response :success

    # User should be confirmed
    user.reload
    assert user.confirmed?
    assert_nil user.confirmation_token

    # Set password
    patch set_password_path, params: {
      password: "password123",
      password_confirmation: "password123"
    }
    assert_redirected_to root_path

    # User should have password now
    user.reload
    assert_not_nil user.password_digest

    # Should be able to log in
    delete logout_path if session[:session_id]

    post login_path, params: {
      email_address: "test@example.com",
      password: "password123"
    }
    assert_redirected_to root_path
  end

  test "cannot login without confirmation" do
    # Create unconfirmed user
    user = User.create!(
      email_address: "unconfirmed@example.com",
      password: "password123",
      confirmed_at: nil
    )

    # Try to login
    post login_path, params: {
      email_address: "unconfirmed@example.com",
      password: "password123"
    }
    assert_redirected_to signup_path
    assert_equal "Please confirm your email address first.", flash[:alert]
  end

  test "resends confirmation email for existing unconfirmed user" do
    # Create unconfirmed user
    user = User.create!(
      email_address: "existing@example.com",
      confirmed_at: nil
    )
    old_token = user.confirmation_token

    # Try to signup again with same email
    assert_no_difference "User.count" do
      post signup_path, params: { email_address: "existing@example.com" }
    end
    assert_redirected_to check_email_path

    # Token should be updated
    user.reload
    assert_not_equal old_token, user.confirmation_token
  end

  test "prevents signup with confirmed email" do
    # Create confirmed user
    user = User.create!(
      email_address: "confirmed@example.com",
      password: "password123",
      confirmed_at: Time.current
    )

    # Try to signup with same email
    assert_no_difference "User.count" do
      post signup_path, params: { email_address: "confirmed@example.com" }
    end
    assert_redirected_to signup_path
  end

end
