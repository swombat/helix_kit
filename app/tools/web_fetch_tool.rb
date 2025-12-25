class WebFetchTool < RubyLLM::Tool

  description "Fetch and read content from a web page"

  param :url, type: :string, desc: "The URL to fetch", required: true

  def execute(url:)
    require "net/http"
    require "uri"

    uri = URI.parse(url)

    # Basic validation
    unless uri.is_a?(URI::HTTP) || uri.is_a?(URI::HTTPS)
      return { error: "Invalid URL: must be http or https" }
    end

    # Fetch with reasonable timeouts
    response = Net::HTTP.start(uri.host, uri.port,
                              use_ssl: uri.scheme == "https",
                              open_timeout: 5,
                              read_timeout: 10) do |http|
      request = Net::HTTP::Get.new(uri)
      request["User-Agent"] = "HelixKit/1.0"
      http.request(request)
    end

    if response.is_a?(Net::HTTPSuccess)
      # Strip HTML tags and truncate for LLM context limits
      content = ActionView::Base.full_sanitizer.sanitize(response.body)
      content = content.strip.first(40000)  # ~10k tokens

      {
        content: content,
        url: url,
        fetched_at: Time.current.iso8601
      }
    elsif response.is_a?(Net::HTTPRedirection)
      # Handle redirects transparently
      {
        redirect: response["location"],
        original_url: url
      }
    else
      {
        error: "HTTP #{response.code}: #{response.message}",
        url: url
      }
    end
  rescue => e
    # Let the LLM handle error messaging to user
    { error: e.message, url: url }
  end

end
