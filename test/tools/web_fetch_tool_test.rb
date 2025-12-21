require "test_helper"

class WebFetchToolTest < ActiveSupport::TestCase

  def setup
    @tool = WebFetchTool.new
  end

  test "tool can be instantiated" do
    assert_instance_of WebFetchTool, @tool
  end

  test "tool responds to execute" do
    assert_respond_to @tool, :execute
  end

  test "rejects non-HTTP URLs" do
    result = @tool.execute(url: "ftp://example.com")

    assert result[:error].present?
    assert_match /Invalid URL/, result[:error]
  end

  test "handles malformed URLs" do
    result = @tool.execute(url: "not a url at all")

    assert result[:error].present?
  end

  test "returns error for network failures" do
    # Use a non-routable IP address (RFC 5737)
    result = @tool.execute(url: "http://192.0.2.1")

    assert result[:error].present?
    assert_equal "http://192.0.2.1", result[:url]
  end

  # Integration test with a real request (using VCR in the future)
  # This test is commented out to avoid making actual HTTP requests in CI
  # test "fetches content from valid URL" do
  #   skip "Requires VCR cassette or live HTTP access"
  #   result = @tool.execute(url: "https://example.com")
  #
  #   assert_equal "https://example.com", result[:url]
  #   assert result[:content].present?
  #   assert result[:fetched_at].present?
  # end

end
