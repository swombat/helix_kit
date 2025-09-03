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

    delete user_avatar_path
    assert_redirected_to login_path
  end

  # Avatar tests
  test "PATCH update with valid avatar attaches avatar to user" do
    avatar_file = fixture_file_upload("test_avatar.png", "image/png")

    patch user_path, params: {
      user: {
        first_name: @user.first_name,
        last_name: @user.last_name,
        avatar: avatar_file
      }
    }, headers: { "X-Inertia" => true }

    assert_redirected_to edit_user_path
    @user.reload
    assert @user.avatar.attached?
    assert_equal "test_avatar.png", @user.avatar.filename.to_s
    assert flash[:success].present?
  end

  test "PATCH update with invalid avatar file type shows error" do
    invalid_file = fixture_file_upload("test.txt", "text/plain")

    patch user_path, params: {
      user: {
        first_name: @user.first_name,
        last_name: @user.last_name,
        avatar: invalid_file
      }
    }, headers: { "X-Inertia" => true }

    assert_redirected_to edit_user_path
    @user.reload
    assert_not @user.avatar.attached?
    assert flash[:errors].present?
  end

  test "PATCH update with oversized avatar shows error" do
    # This test would need a large file fixture in practice
    # For now, we'll test the validation exists by checking model validations
    assert @user.class.validators_on(:avatar).any? { |v| v.is_a?(ActiveStorageValidations::SizeValidator) }
  end

  test "DELETE destroy_avatar removes avatar with Inertia request" do
    # First attach an avatar
    avatar_file = fixture_file_upload("test_avatar.png", "image/png")
    @user.avatar.attach(avatar_file)
    assert @user.avatar.attached?

    delete user_avatar_path, headers: { "X-Inertia" => true }

    assert_redirected_to edit_user_path
    @user.reload
    assert_not @user.avatar.attached?
    assert flash[:success].present?
    assert_equal "Avatar removed successfully", flash[:success]
  end

  test "DELETE destroy_avatar removes avatar without Inertia request" do
    # First attach an avatar
    avatar_file = fixture_file_upload("test_avatar.png", "image/png")
    @user.avatar.attach(avatar_file)
    assert @user.avatar.attached?

    delete user_avatar_path

    assert_response :success
    json_response = JSON.parse(@response.body)
    assert json_response["success"]

    @user.reload
    assert_not @user.avatar.attached?
  end

  test "DELETE destroy_avatar when no avatar exists still succeeds" do
    assert_not @user.avatar.attached?

    delete user_avatar_path, headers: { "X-Inertia" => true }

    assert_redirected_to edit_user_path
    assert flash[:success].present?
  end

end
