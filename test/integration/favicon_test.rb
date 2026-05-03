require "test_helper"

class FaviconTest < ActionDispatch::IntegrationTest

  test "serves the svg favicon from public" do
    get "/favicon.svg"

    assert_response :success
    assert_equal "image/svg+xml", response.media_type
    assert_includes response.body, "#307c85"
    assert_includes response.body, "#f15d61"
    assert_includes response.body, "KIT"
  end

  test "falls back to the controller when requesting /favicon" do
    get "/favicon"

    assert_response :success
    assert_match(/image\/(vnd.microsoft.icon|x-icon|png|svg\+xml)/, response.headers["Content-Type"])
  end

  test "serves the ico favicon from public" do
    get "/favicon.ico"

    assert_response :success
    assert_match(/image\/(vnd.microsoft.icon|x-icon)/, response.headers["Content-Type"])
  end

  test "serves the apple touch icon from public" do
    get "/apple-touch-icon.png"

    assert_response :success
    assert_equal "image/png", response.media_type
  end

  test "returns not found for unsupported favicon formats" do
    get "/favicon.webp"

    assert_response :not_found
  end

end
