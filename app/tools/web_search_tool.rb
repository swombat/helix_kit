require "net/http"
require "json"

class WebSearchTool < RubyLLM::Tool

  RESULT_LIMIT = 10
  OPEN_TIMEOUT = 10
  READ_TIMEOUT = 15

  description "Search the web for information. Returns URLs with titles and snippets. Use web_fetch to read full content from promising results."

  param :query, type: :string, desc: "The search query", required: true

  def execute(query:)
    response = fetch_results(query)

    return error_response("HTTP #{response.code}: #{response.message}", query) unless response.is_a?(Net::HTTPSuccess)

    parse_results(response.body, query)
  rescue JSON::ParserError
    error_response("Invalid response from search service", query)
  rescue => e
    error_response(e.message, query)
  end

  private

  def fetch_results(query)
    uri = build_uri(query)

    Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https",
                    open_timeout: OPEN_TIMEOUT, read_timeout: READ_TIMEOUT) do |http|
      request = Net::HTTP::Get.new(uri)
      request["User-Agent"] = "HelixKit/1.0"
      http.request(request)
    end
  end

  def build_uri(query)
    uri = URI("#{searxng_instance_url}/search")
    uri.query = URI.encode_www_form(q: query, format: "json")
    uri
  end

  def parse_results(body, query)
    data = JSON.parse(body)

    {
      query: query,
      results: data["results"].first(RESULT_LIMIT).map { |r| format_result(r) },
      total_results: data["number_of_results"]
    }
  end

  def format_result(result)
    {
      url: result["url"],
      title: result["title"],
      snippet: result["content"]
    }
  end

  def error_response(message, query)
    { error: message, query: query }
  end

  def searxng_instance_url
    Rails.application.credentials.dig(:searxng, :instance_url) ||
      raise("SearXNG URL not configured. Add searxng.instance_url to Rails credentials.")
  end

end
