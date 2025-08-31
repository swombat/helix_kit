require "test_helper"

class UsersControllerTest < ActionDispatch::IntegrationTest

  setup do
    @user = users(:user_1)
    # Sign in by posting to login path
    post login_path, params: {
      email_address: @user.email_address,
      password: "password"
    }
    # Verify login was successful
    assert_redirected_to root_path
  end

  test "GET edit renders user edit page" do
    get edit_user_path
    assert_response :success
    assert_equal "user/edit", @response.parsed_body["component"]
  end

  test "PATCH update with valid params updates user" do
    patch user_path, params: {
      user: {
        first_name: "Updated",
        last_name: "Name",
        timezone: "UTC"
      }
    }

    assert_redirected_to edit_user_path
    @user.reload
    assert_equal "Updated", @user.first_name
    assert_equal "Name", @user.last_name
    assert_equal "UTC", @user.timezone
    assert flash[:success].present?
  end

  test "PATCH update with theme preference updates theme and sets cookie" do
    patch user_path, params: {
      user: {
        first_name: @user.first_name,
        last_name: @user.last_name,
        preferences: { theme: "dark" }
      }
    }

    assert_redirected_to edit_user_path
    @user.reload
    assert_equal "dark", @user.theme
    assert_equal "dark", cookies[:theme]
    assert flash[:success].present?
  end

  test "PATCH update with invalid theme shows error" do
    patch user_path, params: {
      user: {
        first_name: @user.first_name,
        last_name: @user.last_name,
        preferences: { theme: "invalid" }
      }
    }

    assert_redirected_to edit_user_path
    @user.reload
    assert_not_equal "invalid", @user.theme
    assert flash[:errors].present?
  end

  test "PATCH update without theme preference does not set cookie" do
    # Clear existing theme cookie
    cookies.delete(:theme)

    patch user_path, params: {
      user: {
        first_name: "Updated",
        last_name: "Name"
      }
    }

    assert_redirected_to edit_user_path
    assert_nil cookies[:theme]
  end

  test "theme cookie has correct attributes" do
    patch user_path, params: {
      user: {
        first_name: @user.first_name,
        last_name: @user.last_name,
        preferences: { theme: "light" }
      }
    }

    # Cookie should be set with proper attributes
    cookie_jar = ActionDispatch::Cookies::CookieJar.build(@request, cookies.to_hash)
    theme_cookie = cookie_jar.instance_variable_get(:@cookies)["theme"]

    assert_equal "light", theme_cookie[:value]
    assert theme_cookie[:expires] > 11.months.from_now
    assert_equal true, theme_cookie[:httponly]
    # secure should be false in test environment
    assert_equal false, theme_cookie[:secure]
  end

  test "GET edit_password renders password edit page" do
    get edit_password_user_path
    assert_response :success
    assert_equal "user/edit_password", @response.parsed_body["component"]
  end

  test "PATCH update_password with valid current password updates password" do
    patch update_password_user_path, params: {
      current_password: "password123",
      password: "newpassword123",
      password_confirmation: "newpassword123"
    }

    assert_redirected_to edit_user_path
    @user.reload
    assert @user.authenticate("newpassword123")
    assert flash[:success].present?
  end

  test "PATCH update_password with invalid current password shows error" do
    patch update_password_user_path, params: {
      current_password: "wrongpassword",
      password: "newpassword123",
      password_confirmation: "newpassword123"
    }

    assert_redirected_to edit_password_user_path
    assert flash[:errors].present?
    assert flash[:errors].include?("Current password is incorrect")
  end

  test "PATCH update_password with mismatched confirmation shows error" do
    patch update_password_user_path, params: {
      current_password: "password123",
      password: "newpassword123",
      password_confirmation: "different"
    }

    assert_redirected_to edit_password_user_path
    assert flash[:errors].present?
  end

  test "controllers require authentication" do
    # Sign out by deleting the session
    delete logout_path

    get edit_user_path
    assert_redirected_to login_path

    patch user_path, params: { user: { first_name: "Test" } }
    assert_redirected_to login_path

    get edit_password_user_path
    assert_redirected_to login_path

    patch update_password_user_path
    assert_redirected_to login_path
  end

end
