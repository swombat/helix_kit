require "test_helper"

class Users::PasswordsControllerTest < ActionDispatch::IntegrationTest

  setup do
    @user = users(:user_1)
    post login_path, params: {
      email_address: @user.email_address,
      password: "password123"
    }
    assert_redirected_to root_path
  end

  test "GET edit renders password edit page" do
    get edit_user_password_path
    assert_response :success
    assert_equal "user/edit_password", inertia_component
  end

  test "PATCH update with valid current password updates password" do
    patch user_password_path, params: {
      current_password: "password123",
      password: "newpassword123",
      password_confirmation: "newpassword123"
    }

    assert_redirected_to edit_user_path
    @user.reload
    assert @user.authenticate("newpassword123")
    assert flash[:success].present?
  end

  test "PATCH update with invalid current password shows error" do
    patch user_password_path, params: {
      current_password: "wrongpassword",
      password: "newpassword123",
      password_confirmation: "newpassword123"
    }

    assert_redirected_to edit_user_password_path
    assert flash[:errors].present?
    assert flash[:errors].include?("Current password is incorrect")
  end

  test "PATCH update with mismatched confirmation shows error" do
    patch user_password_path, params: {
      current_password: "password123",
      password: "newpassword123",
      password_confirmation: "different"
    }

    assert_redirected_to edit_user_password_path
    assert flash[:errors].present?
  end

  test "requires authentication" do
    delete logout_path

    get edit_user_password_path
    assert_redirected_to login_path

    patch user_password_path
    assert_redirected_to login_path
  end

end
