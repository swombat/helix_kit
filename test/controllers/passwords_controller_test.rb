require "test_helper"

class PasswordsControllerTest < ActionDispatch::IntegrationTest

  setup do
    @user = users(:user_1)
  end

  test "should get new password reset page" do
    get new_password_path
    assert_response :success
    assert_equal "passwords/new", inertia_component
  end

  test "should create password reset request for existing user" do
    assert_enqueued_emails 1 do
      post passwords_path, params: { email_address: @user.email_address }
    end
    assert_redirected_to login_path
    assert_equal "Password reset instructions sent (if user with that email address exists).", flash[:notice]
  end

  test "should not reveal if user exists when requesting password reset" do
    post passwords_path, params: { email_address: "nonexistent@example.com" }
    assert_redirected_to login_path
    assert_equal "Password reset instructions sent (if user with that email address exists).", flash[:notice]
    assert_no_enqueued_emails
  end

  test "should get password reset edit page with valid token" do
    @user.send_password_reset
    token = @user.reload.password_reset_token_for_url
    get edit_password_path(token)
    assert_response :success
    assert_equal "passwords/edit", inertia_component
    assert_equal token, inertia_shared_props["token"]
  end

  test "should redirect to new password path with invalid token" do
    get edit_password_path("invalid-token")
    assert_redirected_to new_password_path
    assert_equal "Password reset link is invalid or has expired.", flash[:alert]
  end

  test "should update password with valid token and matching passwords" do
    @user.send_password_reset
    token = @user.reload.password_reset_token_for_url

    patch password_path(token), params: {
      password: "newpassword123",
      password_confirmation: "newpassword123"
    }

    assert_redirected_to login_path
    assert_equal "Password has been reset.", flash[:notice]

    # Verify the token was cleared
    @user.reload
    assert_nil @user.password_reset_token_for_url
    assert_nil @user.password_reset_sent_at

    # Verify the new password works
    post login_path, params: {
      email_address: @user.email_address,
      password: "newpassword123"
    }
    assert_redirected_to root_path
  end

  test "should not update password with mismatched confirmation" do
    @user.send_password_reset
    token = @user.reload.password_reset_token_for_url

    patch password_path(token), params: {
      password: "newpassword123",
      password_confirmation: "differentpassword"
    }

    assert_redirected_to edit_password_path(token)

    # Follow the redirect to check for errors
    follow_redirect!
    assert inertia_shared_props["errors"].present?
  end

  test "should not update password with invalid token" do
    patch password_path("invalid-token"), params: {
      password: "newpassword123",
      password_confirmation: "newpassword123"
    }

    assert_redirected_to new_password_path
    assert_equal "Password reset link is invalid or has expired.", flash[:alert]
  end

  test "should not update password with expired token" do
    @user.send_password_reset
    token = @user.reload.password_reset_token_for_url

    # Simulate token expiration by setting sent_at to over 2 hours ago
    @user.update_column(:password_reset_sent_at, 3.hours.ago)

    get edit_password_path(token)
    assert_redirected_to new_password_path
    assert_equal "Password reset link is invalid or has expired.", flash[:alert]
  end

  test "password reset pages do not require authentication" do
    get new_password_path
    assert_response :success

    post passwords_path, params: { email_address: @user.email_address }
    assert_redirected_to login_path

    @user.send_password_reset
    token = @user.reload.password_reset_token_for_url
    get edit_password_path(token)
    assert_response :success
  end

end
