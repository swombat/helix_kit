require "test_helper"

class FaviconControllerTest < ActionDispatch::IntegrationTest

  test "should get favicon as png by default" do
    get favicon_path(format: "png")
    assert_response :success
    assert_match(/image\/(png|svg)/, @response.headers["Content-Type"])
  end

  test "should get favicon as ico" do
    get favicon_path(format: "ico")
    assert_response :success
    assert_match(/image\/(png|svg)/, @response.headers["Content-Type"])
  end

  test "should get favicon as svg" do
    get favicon_path(format: "svg")
    assert_response :success
    assert_equal "image/svg+xml", @response.headers["Content-Type"]
  end

  test "should get favicon without format defaults to ico" do
    get "/favicon"
    assert_response :success
    assert_match(/image\/(png|svg)/, @response.headers["Content-Type"])
  end

  test "should return 404 for unsupported format" do
    get favicon_path(format: "webp")
    assert_response :not_found
  end

  test "favicon endpoint does not require authentication" do
    get favicon_path(format: "png")
    assert_response :success
  end

end
