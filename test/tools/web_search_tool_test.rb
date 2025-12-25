require "test_helper"
require "webmock/minitest"

class WebSearchToolTest < ActiveSupport::TestCase

  setup do
    @tool = WebSearchTool.new
    # Stub the private method to return test URL
    @tool.define_singleton_method(:searxng_instance_url) { "https://searxng.example.com" }
  end

  test "tool can be instantiated" do
    assert_instance_of WebSearchTool, @tool
  end

  test "tool responds to execute" do
    assert_respond_to @tool, :execute
  end

  test "returns search results for valid query" do
    stub_searxng_success

    result = @tool.execute(query: "ruby on rails")

    assert_equal "ruby on rails", result[:query]
    assert_equal 2, result[:results].length
    assert_equal "https://rubyonrails.org", result[:results].first[:url]
    assert_equal "Ruby on Rails", result[:results].first[:title]
    assert_equal "A web framework", result[:results].first[:snippet]
  end

  test "limits results to configured maximum" do
    stub_searxng_with_many_results(15)

    result = @tool.execute(query: "test")

    assert_equal 10, result[:results].length
  end

  test "returns error with query for failed request" do
    stub_request(:get, /searxng/).to_return(status: 500, body: "", headers: {})

    result = @tool.execute(query: "test")

    assert_match(/500/, result[:error])
    assert_equal "test", result[:query]
  end

  test "returns error for timeout" do
    stub_request(:get, /searxng/).to_timeout

    result = @tool.execute(query: "test")

    assert result[:error].present?
    assert_equal "test", result[:query]
  end

  test "handles empty results" do
    stub_searxng_empty

    result = @tool.execute(query: "obscure query")

    assert_equal [], result[:results]
    assert_equal 0, result[:total_results]
  end

  test "handles invalid JSON response" do
    stub_request(:get, /searxng/)
      .to_return(status: 200, body: "not json", headers: {})

    result = @tool.execute(query: "test")

    assert_equal "Invalid response from search service", result[:error]
    assert_equal "test", result[:query]
  end

  test "returns error when SearXNG URL not configured" do
    # Create a fresh tool and simulate missing configuration
    tool = WebSearchTool.new
    tool.define_singleton_method(:searxng_instance_url) do
      nil || raise("SearXNG URL not configured. Add searxng.instance_url to Rails credentials.")
    end

    result = tool.execute(query: "test")

    assert_match(/SearXNG URL not configured/, result[:error])
    assert_equal "test", result[:query]
  end

  private

  def stub_searxng_success
    stub_request(:get, /searxng/)
      .to_return(status: 200, body: searxng_response(2).to_json,
                 headers: { "Content-Type" => "application/json" })
  end

  def stub_searxng_with_many_results(count)
    stub_request(:get, /searxng/)
      .to_return(status: 200, body: searxng_response(count).to_json)
  end

  def stub_searxng_empty
    stub_request(:get, /searxng/)
      .to_return(status: 200, body: { query: "test", number_of_results: 0, results: [] }.to_json)
  end

  def searxng_response(count)
    {
      query: "ruby on rails",
      number_of_results: count * 100,
      results: Array.new(count) { |i| sample_result(i) }
    }
  end

  def sample_result(index)
    url = index.zero? ? "https://rubyonrails.org" : "https://example#{index}.com"
    title = index.zero? ? "Ruby on Rails" : "Result #{index}"
    content = index.zero? ? "A web framework" : "Content #{index}"
    { url: url, title: title, content: content }
  end

end
