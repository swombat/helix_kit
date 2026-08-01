require "test_helper"

class Admin::NoticesControllerTest < ActionDispatch::IntegrationTest

  setup do
    @admin = users(:site_admin_user)
    @user = users(:user_1)
  end

  test "site admin can view and post system notices" do
    sign_in @admin

    get admin_notices_path
    assert_response :success

    assert_difference "Notice.count", 1 do
      post admin_notices_path, params: {
        notice: { body: "Site maintenance tonight.", expires_in_days: "3" }
      }
    end

    notice = Notice.last
    assert_equal "system", notice.scope
    assert_nil notice.account
    assert_equal @admin, notice.created_by
    assert_redirected_to admin_notices_path
  end

  test "site notice management excludes platform-generated notices" do
    sign_in @admin
    site_notice = Notice.create!(
      scope: "system",
      notice_type: "site_renamed",
      expires_at: 30.days.from_now
    )

    get admin_notices_path

    assert_response :success
    assert_empty inertia_shared_props.fetch("notices")

    delete admin_notice_path(site_notice)
    assert_response :not_found
    assert site_notice.reload.expires_at.future?
  end

  test "site admin can end a system notice" do
    sign_in @admin
    notice = Notice.create!(
      scope: "system",
      notice_type: "announcement",
      body: "Temporary site news",
      expires_at: 1.day.from_now
    )

    delete admin_notice_path(notice)

    assert_redirected_to admin_notices_path
    assert_not_includes Notice.active, notice
  end

  test "non-admin cannot manage system notices" do
    sign_in @user

    get admin_notices_path
    assert_redirected_to root_path

    assert_no_difference "Notice.count" do
      post admin_notices_path, params: {
        notice: { body: "Nope", expires_in_days: "30" }
      }
    end
    assert_redirected_to root_path
  end

end
