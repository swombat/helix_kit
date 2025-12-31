require "test_helper"
require "webmock/minitest"

class WebToolTest < ActiveSupport::TestCase

  setup do
    @tool = WebTool.new
    # Stub the private method to return test URL
    @tool.define_singleton_method(:searxng_instance_url) { "https://searxng.test" }
  end

  # ========================================
  # SEARCH ACTION TESTS
  # ========================================

  test "search returns results with type-discriminated response" do
    stub_searxng_success

    result = @tool.execute(action: "search", query: "rails 8")

    assert_equal "search_results", result[:type]
    assert_equal "rails 8", result[:query]
    assert result[:results].is_a?(Array)
    assert_equal 2, result[:results].length
    assert_equal "https://rubyonrails.org", result[:results].first[:url]
    assert_equal "Ruby on Rails", result[:results].first[:title]
    assert_equal "A web framework", result[:results].first[:snippet]
    assert_equal 100, result[:total_results]
  end

  test "search without query returns self-correcting param error" do
    result = @tool.execute(action: "search")

    assert_equal "error", result[:type]
    assert_match(/query is required for search action/, result[:error])
    assert_equal "search", result[:action]
    assert_equal "query", result[:required_param]
    assert_equal %w[search fetch], result[:allowed_actions]
  end

  test "search with blank query returns self-correcting param error" do
    result = @tool.execute(action: "search", query: "   ")

    assert_equal "error", result[:type]
    assert_match(/query is required/, result[:error])
    assert_equal "query", result[:required_param]
  end

  test "search respects rate limit of MAX_SEARCHES_PER_SESSION" do
    stub_searxng_success

    # Execute up to the limit
    WebTool::MAX_SEARCHES_PER_SESSION.times do |i|
      result = @tool.execute(action: "search", query: "query #{i}")
      assert_equal "search_results", result[:type], "Search #{i + 1} should succeed"
      assert_nil result[:error]
    end

    # Next search should fail with rate limit error
    result = @tool.execute(action: "search", query: "one too many")
    assert_equal "error", result[:type]
    assert_match(/Search limit reached/, result[:error])
    assert_match(/#{WebTool::MAX_SEARCHES_PER_SESSION}/, result[:error])
    assert_equal "one too many", result[:query]
  end

  test "search limits results to RESULT_LIMIT" do
    stub_searxng_with_many_results(25)

    result = @tool.execute(action: "search", query: "popular topic")

    assert_equal "search_results", result[:type]
    assert_equal WebTool::RESULT_LIMIT, result[:results].length
  end

  test "search handles HTTP error responses" do
    stub_request(:get, /searxng/)
      .to_return(status: 500, body: "Internal Server Error", headers: {})

    result = @tool.execute(action: "search", query: "test query")

    assert_equal "error", result[:type]
    assert_match(/HTTP 500/, result[:error])
    assert_equal "test query", result[:query]
  end

  test "search handles HTTP 404 error" do
    stub_request(:get, /searxng/)
      .to_return(status: 404, body: "Not Found", headers: {})

    result = @tool.execute(action: "search", query: "test")

    assert_equal "error", result[:type]
    assert_match(/HTTP 404/, result[:error])
    assert_equal "test", result[:query]
  end

  test "search handles network timeout" do
    stub_request(:get, /searxng/).to_timeout

    result = @tool.execute(action: "search", query: "timeout query")

    assert_equal "error", result[:type]
    assert result[:error].present?
    assert_equal "timeout query", result[:query]
  end

  test "search handles invalid JSON response" do
    stub_request(:get, /searxng/)
      .to_return(status: 200, body: "not valid json", headers: {})

    result = @tool.execute(action: "search", query: "test")

    assert_equal "error", result[:type]
    assert_equal "Invalid response from search service", result[:error]
    assert_equal "test", result[:query]
  end

  test "search handles empty results" do
    stub_request(:get, /searxng/)
      .to_return(
        status: 200,
        body: { query: "obscure", number_of_results: 0, results: [] }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    result = @tool.execute(action: "search", query: "obscure query")

    assert_equal "search_results", result[:type]
    assert_equal "obscure query", result[:query]
    assert_equal [], result[:results]
    assert_equal 0, result[:total_results]
  end

  test "search includes query in error responses" do
    stub_request(:get, /searxng/).to_raise(StandardError.new("Connection failed"))

    result = @tool.execute(action: "search", query: "failed query")

    assert_equal "error", result[:type]
    assert_match(/Connection failed/, result[:error])
    assert_equal "failed query", result[:query]
  end

  # ========================================
  # FETCH ACTION TESTS
  # ========================================

  test "fetch returns page content with type-discriminated response" do
    stub_request(:get, "https://example.com/")
      .to_return(status: 200, body: "<html><body><h1>Hello World</h1><p>Test content</p></body></html>")

    result = @tool.execute(action: "fetch", url: "https://example.com")

    assert_equal "fetched_page", result[:type]
    assert_equal "https://example.com", result[:url]
    assert_match(/Hello World/, result[:content])
    assert_match(/Test content/, result[:content])
    assert result[:fetched_at].present?
    # Verify ISO 8601 timestamp format
    assert_match(/\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/, result[:fetched_at])
  end

  test "fetch sanitizes HTML content" do
    stub_request(:get, "https://example.com/")
      .to_return(status: 200, body: "<html><body><script>alert('xss')</script><p>Safe content</p></body></html>")

    result = @tool.execute(action: "fetch", url: "https://example.com")

    assert_equal "fetched_page", result[:type]
    refute_match(/<script>/, result[:content])
    assert_match(/Safe content/, result[:content])
  end

  test "fetch without url returns self-correcting param error" do
    result = @tool.execute(action: "fetch")

    assert_equal "error", result[:type]
    assert_match(/url is required for fetch action/, result[:error])
    assert_equal "fetch", result[:action]
    assert_equal "url", result[:required_param]
    assert_equal %w[search fetch], result[:allowed_actions]
  end

  test "fetch with blank url returns self-correcting param error" do
    result = @tool.execute(action: "fetch", url: "   ")

    assert_equal "error", result[:type]
    assert_match(/url is required/, result[:error])
    assert_equal "url", result[:required_param]
  end

  test "fetch handles HTTP redirects" do
    stub_request(:get, "http://example.com/")
      .to_return(status: 301, headers: { "Location" => "https://example.com/" })

    result = @tool.execute(action: "fetch", url: "http://example.com")

    assert_equal "redirect", result[:type]
    assert_equal "http://example.com", result[:original_url]
    assert_equal "https://example.com/", result[:redirect_url]
  end

  test "fetch handles 302 redirects" do
    stub_request(:get, "http://example.com/old")
      .to_return(status: 302, headers: { "Location" => "http://example.com/new" })

    result = @tool.execute(action: "fetch", url: "http://example.com/old")

    assert_equal "redirect", result[:type]
    assert_equal "http://example.com/old", result[:original_url]
    assert_equal "http://example.com/new", result[:redirect_url]
  end

  test "fetch rejects non-HTTP URLs" do
    result = @tool.execute(action: "fetch", url: "ftp://example.com")

    assert_equal "error", result[:type]
    assert_match(/Invalid URL: must be http or https/, result[:error])
    assert_equal "ftp://example.com", result[:url]
  end

  test "fetch rejects file URLs" do
    result = @tool.execute(action: "fetch", url: "file:///etc/passwd")

    assert_equal "error", result[:type]
    assert_match(/Invalid URL/, result[:error])
  end

  test "fetch handles malformed URLs" do
    result = @tool.execute(action: "fetch", url: "not a valid url")

    assert_equal "error", result[:type]
    assert result[:error].present?
    assert_equal "not a valid url", result[:url]
  end

  test "fetch handles HTTP error responses" do
    stub_request(:get, "https://example.com/")
      .to_return(status: 404, body: "Not Found")

    result = @tool.execute(action: "fetch", url: "https://example.com")

    assert_equal "error", result[:type]
    assert_match(/HTTP 404/, result[:error])
    assert_equal "https://example.com", result[:url]
  end

  test "fetch handles HTTP 500 error" do
    stub_request(:get, "https://example.com/")
      .to_return(status: 500, body: "Internal Server Error")

    result = @tool.execute(action: "fetch", url: "https://example.com")

    assert_equal "error", result[:type]
    assert_match(/HTTP 500/, result[:error])
  end

  test "fetch handles network timeout" do
    stub_request(:get, "https://example.com/").to_timeout

    result = @tool.execute(action: "fetch", url: "https://example.com")

    assert_equal "error", result[:type]
    assert result[:error].present?
    assert_equal "https://example.com", result[:url]
  end

  test "fetch handles connection refused" do
    stub_request(:get, "https://example.com/")
      .to_raise(Errno::ECONNREFUSED)

    result = @tool.execute(action: "fetch", url: "https://example.com")

    assert_equal "error", result[:type]
    assert result[:error].present?
    assert_equal "https://example.com", result[:url]
  end

  test "fetch truncates content to 40000 characters" do
    long_content = "<html><body>#{'a' * 50000}</body></html>"
    stub_request(:get, "https://example.com/")
      .to_return(status: 200, body: long_content)

    result = @tool.execute(action: "fetch", url: "https://example.com")

    assert_equal "fetched_page", result[:type]
    assert result[:content].length <= 40000
  end

  # ========================================
  # VALIDATION TESTS
  # ========================================

  test "invalid action returns self-correcting error" do
    result = @tool.execute(action: "crawl", query: "test")

    assert_equal "error", result[:type]
    assert_match(/Invalid action 'crawl'/, result[:error])
    assert_equal %w[search fetch], result[:allowed_actions]
  end

  test "invalid action with different name" do
    result = @tool.execute(action: "extract", url: "https://example.com")

    assert_equal "error", result[:type]
    assert_match(/Invalid action 'extract'/, result[:error])
    assert_equal %w[search fetch], result[:allowed_actions]
  end

  test "empty action returns self-correcting error" do
    result = @tool.execute(action: "", query: "test")

    assert_equal "error", result[:type]
    assert_match(/Invalid action/, result[:error])
    assert_equal %w[search fetch], result[:allowed_actions]
  end

  # ========================================
  # TYPE DISCRIMINATION TESTS
  # ========================================

  test "all successful responses include type field" do
    stub_searxng_success
    stub_request(:get, "https://example.com/")
      .to_return(status: 200, body: "<html><body>Test</body></html>")
    stub_request(:get, "http://redirect.com/")
      .to_return(status: 301, headers: { "Location" => "https://example.com/" })

    search_result = @tool.execute(action: "search", query: "test")
    assert search_result.key?(:type)
    assert_equal "search_results", search_result[:type]

    fetch_result = @tool.execute(action: "fetch", url: "https://example.com")
    assert fetch_result.key?(:type)
    assert_equal "fetched_page", fetch_result[:type]

    redirect_result = @tool.execute(action: "fetch", url: "http://redirect.com")
    assert redirect_result.key?(:type)
    assert_equal "redirect", redirect_result[:type]
  end

  test "all error responses include type field" do
    invalid_action = @tool.execute(action: "invalid", query: "test")
    assert_equal "error", invalid_action[:type]

    missing_query = @tool.execute(action: "search")
    assert_equal "error", missing_query[:type]

    missing_url = @tool.execute(action: "fetch")
    assert_equal "error", missing_url[:type]

    invalid_url = @tool.execute(action: "fetch", url: "ftp://example.com")
    assert_equal "error", invalid_url[:type]
  end

  # ========================================
  # HELPER METHODS
  # ========================================

  private

  def stub_searxng_success
    stub_request(:get, /searxng/)
      .to_return(
        status: 200,
        body: {
          query: "test",
          number_of_results: 100,
          results: [
            { url: "https://rubyonrails.org", title: "Ruby on Rails", content: "A web framework" },
            { url: "https://guides.rubyonrails.org", title: "Rails Guides", content: "Learn Rails" }
          ]
        }.to_json,
        headers: { "Content-Type" => "application/json" }
      )
  end

  def stub_searxng_with_many_results(count)
    results = Array.new(count) { |i|
      { url: "https://example#{i}.com", title: "Result #{i}", content: "Content #{i}" }
    }

    stub_request(:get, /searxng/)
      .to_return(
        status: 200,
        body: {
          query: "test",
          number_of_results: count * 100,
          results: results
        }.to_json,
        headers: { "Content-Type" => "application/json" }
      )
  end

end
