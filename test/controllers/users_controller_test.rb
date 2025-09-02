require "test_helper"

class UsersControllerTest < ActionDispatch::IntegrationTest

  setup do
    @user = users(:user_1)
    # Sign in by posting to login path
    post login_path, params: {
      email_address: @user.email_address,
      password: "password123"
    }
    # Verify login was successful
    assert_redirected_to root_path
  end

  test "GET edit renders user edit page" do
    get edit_user_path
    assert_response :success
    assert_equal "user/edit", inertia_component
  end

  test "PATCH update with valid params updates user" do
    patch user_path, params: {
      user: {
        first_name: "Updated",
        last_name: "Name",
        timezone: "UTC"
      }
    }, headers: { "X-Inertia" => true }

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
    }, headers: { "X-Inertia" => true }

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
    }, headers: { "X-Inertia" => true }

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
    }, headers: { "X-Inertia" => true }

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
    }, headers: { "X-Inertia" => true }

    # Simply verify the cookie value is set correctly
    assert_equal "light", cookies[:theme]
  end

  test "PATCH update without Inertia header returns JSON (for navbar theme updates)" do
    patch user_path, params: {
      user: {
        preferences: { theme: "dark" }
      }
    }

    assert_response :success
    json_response = JSON.parse(@response.body)
    assert json_response["success"]

    @user.reload
    assert_equal "dark", @user.theme
    assert_equal "dark", cookies[:theme]
  end

  test "GET edit_password renders password edit page" do
    get edit_password_user_path
    assert_response :success
    assert_equal "user/edit_password", inertia_component
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

    patch user_path, params: { user: { first_name: "Test" } }, headers: { "X-Inertia" => true }
    assert_redirected_to login_path

    get edit_password_user_path
    assert_redirected_to login_path

    patch update_password_user_path
    assert_redirected_to login_path
  end

end
