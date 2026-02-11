require "test_helper"

class Users::AvatarsControllerTest < ActionDispatch::IntegrationTest

  setup do
    @user = users(:user_1)
    post login_path, params: {
      email_address: @user.email_address,
      password: "password123"
    }
    assert_redirected_to root_path
  end

  test "DELETE destroy removes avatar with Inertia request" do
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

  test "DELETE destroy removes avatar without Inertia request" do
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

  test "DELETE destroy when no avatar exists still succeeds" do
    assert_not @user.avatar.attached?

    delete user_avatar_path, headers: { "X-Inertia" => true }

    assert_redirected_to edit_user_path
    assert flash[:success].present?
  end

  test "requires authentication" do
    delete logout_path

    delete user_avatar_path
    assert_redirected_to login_path
  end

end
