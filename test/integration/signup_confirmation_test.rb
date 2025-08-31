require "test_helper"

class SignupConfirmationTest < ActionDispatch::IntegrationTest

  test "signup flow with email confirmation" do
    # Visit signup page
    get signup_path
    assert_response :success

    rand_email = "test-#{Time.now.to_i}@example.com"

    # Submit email
    assert_difference "User.count", 1 do
      post signup_path, params: { email_address: rand_email }
    end
    assert_redirected_to check_email_path

    # Check user was created without password
    user = User.last
    assert_equal rand_email, user.email_address
    assert_nil user.password_digest
    assert_not user.confirmed?

    # Confirmation token is now on AccountUser
    account_user = user.personal_account_user
    assert_not_nil account_user.confirmation_token
    assert_not_nil account_user.confirmation_sent_at

    # Visit confirmation link
    get email_confirmation_path(token: account_user.confirmation_token)
    assert_redirected_to set_password_path
    follow_redirect!
    assert_response :success

    # User should be confirmed
    user.reload
    account_user.reload
    assert user.confirmed?
    assert_nil account_user.confirmation_token

    # Set password
    patch set_password_path, params: {
      password: "password123",
      password_confirmation: "password123",
      first_name: "Signup",
      last_name: "Confirmation"
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
    # Use existing unconfirmed user fixture
    user = users(:unconfirmed_user)
    # Set a password for the unconfirmed user
    user.update!(password: "password123")

    # Try to login
    post login_path, params: {
      email_address: user.email_address,
      password: "password123"
    }
    assert_redirected_to signup_path
    assert_equal "Please confirm your email address first.", flash[:alert]
  end

  test "resends confirmation email for existing unconfirmed user" do
    user = users(:unconfirmed_user)
    account_user = user.personal_account_user
    old_token = account_user.confirmation_token

    # Try to signup again with same email
    assert_no_difference "User.count" do
      post signup_path, params: { email_address: user.email_address }
    end
    assert_redirected_to check_email_path

    # Token should be updated
    account_user.reload
    assert_not_equal old_token, account_user.confirmation_token
  end

  test "prevents signup with confirmed email" do
    # Create confirmed user
    user = User.create!(
      email_address: "confirmed-signup-test@example.com",
      password: "password123"
    )
    # Confirm the user's account
    user.personal_account_user.update!(confirmed_at: Time.current)

    # Try to signup with same email
    assert_no_difference "User.count" do
      post signup_path, params: { email_address: "confirmed-signup-test@example.com" }
    end
    assert_redirected_to signup_path
  end

end
