require "net/http"
require "json"
require "uri"

class WebTool < RubyLLM::Tool

  ACTIONS = %w[search fetch].freeze
  RESULT_LIMIT = 10
  MAX_SEARCHES_PER_SESSION = 10
  OPEN_TIMEOUT = 10
  READ_TIMEOUT = 15

  description "Search the web or fetch a page. Use action 'search' with query, or 'fetch' with url."

  param :action, type: :string,
        desc: "search or fetch",
        required: true

  param :query, type: :string,
        desc: "Search query (required for search action)",
        required: false

  param :url, type: :string,
        desc: "URL to fetch (required for fetch action)",
        required: false

  def initialize(chat: nil, current_agent: nil)
    super()
    @chat = chat
    @current_agent = current_agent
    @search_count = 0
  end

  def execute(action:, query: nil, url: nil)
    unless ACTIONS.include?(action)
      return validation_error("Invalid action '#{action}'")
    end

    case action
    when "search" then search(query)
    when "fetch" then fetch(url)
    end
  end

  private

  def search(query)
    return param_error("search", "query") if query.blank?

    @search_count += 1
    if @search_count > MAX_SEARCHES_PER_SESSION
      return { type: "error", error: "Search limit reached (#{MAX_SEARCHES_PER_SESSION} per response)", query: query }
    end

    response = fetch_search_results(query)
    unless response.is_a?(Net::HTTPSuccess)
      return { type: "error", error: "HTTP #{response.code}: #{response.message}", query: query }
    end

    parse_search_results(response.body, query)
  rescue JSON::ParserError
    { type: "error", error: "Invalid response from search service", query: query }
  rescue => e
    { type: "error", error: e.message, query: query }
  end

  def fetch_search_results(query)
    uri = URI("#{searxng_instance_url}/search")
    uri.query = URI.encode_www_form(q: query, format: "json")

    Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https",
                    open_timeout: OPEN_TIMEOUT, read_timeout: READ_TIMEOUT) do |http|
      request = Net::HTTP::Get.new(uri)
      request["User-Agent"] = "HelixKit/1.0"
      http.request(request)
    end
  end

  def parse_search_results(body, query)
    data = JSON.parse(body)
    {
      type: "search_results",
      query: query,
      results: data["results"].first(RESULT_LIMIT).map { |r|
        { url: r["url"], title: r["title"], snippet: r["content"] }
      },
      total_results: data["number_of_results"]
    }
  end

  def searxng_instance_url
    Rails.application.credentials.dig(:searxng, :instance_url) ||
      raise("SearXNG URL not configured")
  end

  def fetch(url)
    return param_error("fetch", "url") if url.blank?

    uri = URI.parse(url)
    unless uri.is_a?(URI::HTTP) || uri.is_a?(URI::HTTPS)
      return { type: "error", error: "Invalid URL: must be http or https", url: url }
    end

    response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https",
                               open_timeout: 5, read_timeout: 10) do |http|
      request = Net::HTTP::Get.new(uri)
      request["User-Agent"] = "HelixKit/1.0"
      http.request(request)
    end

    handle_fetch_response(response, url)
  rescue => e
    { type: "error", error: e.message, url: url }
  end

  def handle_fetch_response(response, url)
    case response
    when Net::HTTPSuccess
      content = ActionView::Base.full_sanitizer.sanitize(response.body)
      { type: "fetched_page", url: url, content: content.strip.first(40000), fetched_at: Time.current.iso8601 }
    when Net::HTTPRedirection
      { type: "redirect", original_url: url, redirect_url: response["location"] }
    else
      { type: "error", error: "HTTP #{response.code}: #{response.message}", url: url }
    end
  end

  def validation_error(message)
    { type: "error", error: message, allowed_actions: ACTIONS }
  end

  def param_error(action, missing_param)
    {
      type: "error",
      error: "#{missing_param} is required for #{action} action",
      action: action,
      required_param: missing_param,
      allowed_actions: ACTIONS
    }
  end

end
