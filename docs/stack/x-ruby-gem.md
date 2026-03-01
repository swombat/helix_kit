# X Ruby Gem (`x`) - Twitter/X API Integration Guide

This document covers using the `x` gem (sferik/x-ruby) to interact with the X (Twitter) API from Ruby/Rails.

- **GitHub**: https://github.com/sferik/x-ruby
- **Documentation**: https://sferik.github.io/x-ruby/
- **X Developer Portal**: https://developer.x.com
- **Version**: ~750 lines of code, zero runtime dependencies, MIT License

## Overview

The `x` gem is a lightweight, dependency-free Ruby interface to the X API. It is a complete rewrite of the older `twitter` gem and emphasizes simplicity and performance. It supports OAuth 1.0a and OAuth 2.0 authentication, thread-safe operation, error handling, rate limit management, and configurable timeouts.

## 1. Installation

Add to your `Gemfile`:

```ruby
gem "x"
```

Then run:

```bash
bundle install
```

Or install directly:

```bash
gem install x
```

## 2. Credentials Setup

Obtain credentials from the [X Developer Portal](https://developer.x.com). You need:

- **API Key** (also called Consumer Key)
- **API Key Secret** (also called Consumer Secret)
- **Access Token**
- **Access Token Secret**

Store credentials in Rails credentials (never hardcode or commit them):

```bash
rails credentials:edit
```

```yaml
# config/credentials.yml.enc
x:
  api_key: "YOUR_API_KEY"
  api_key_secret: "YOUR_API_KEY_SECRET"
  access_token: "YOUR_ACCESS_TOKEN"
  access_token_secret: "YOUR_ACCESS_TOKEN_SECRET"
```

## 3. Client Configuration

### OAuth 1.0a (Standard — for posting on behalf of a user)

```ruby
require "x"

x_client = X::Client.new(
  api_key:             Rails.application.credentials.x[:api_key],
  api_key_secret:      Rails.application.credentials.x[:api_key_secret],
  access_token:        Rails.application.credentials.x[:access_token],
  access_token_secret: Rails.application.credentials.x[:access_token_secret]
)
```

### OAuth 2.0 Bearer Token (for read-only app-level requests)

```ruby
x_client = X::Client.new(
  bearer_token: Rails.application.credentials.x[:bearer_token]
)
```

### OAuth 2.0 with Refresh Token

```ruby
x_client = X::Client.new(
  client_id:     Rails.application.credentials.x[:client_id],
  client_secret: Rails.application.credentials.x[:client_secret],
  refresh_token: Rails.application.credentials.x[:refresh_token]
)
```

### Full Configuration Options

```ruby
x_client = X::Client.new(
  api_key:             "...",
  api_key_secret:      "...",
  access_token:        "...",
  access_token_secret: "...",

  # Optional configuration
  base_url:      "https://api.twitter.com/2/",  # default
  open_timeout:  10,   # seconds
  read_timeout:  10,   # seconds
  write_timeout: 10,   # seconds
  proxy_url:     nil,  # e.g. "http://proxy.example.com:8080"
  max_redirects: 3,
  debug_output:  $stderr  # IO object for HTTP debug output
)
```

## 4. Posting Tweets (Primary Use Case)

### Basic Tweet

```ruby
response = x_client.post("tweets", '{"text":"Hello, World!"}')
# Returns:
# {
#   "data" => {
#     "edit_history_tweet_ids" => ["1234567890123456789"],
#     "id"  => "1234567890123456789",
#     "text" => "Hello, World!"
#   }
# }

tweet_id = response["data"]["id"]
```

### Tweet with Ruby Hash (using JSON serialization)

```ruby
require "json"

payload = { text: "Hello from Rails!" }.to_json
response = x_client.post("tweets", payload)
tweet_id = response["data"]["id"]
```

### Reply to a Tweet

```ruby
payload = {
  text: "This is a reply!",
  reply: {
    in_reply_to_tweet_id: "ORIGINAL_TWEET_ID"
  }
}.to_json

response = x_client.post("tweets", payload)
```

### Tweet with Media (requires separate media upload)

Media must first be uploaded via the v1.1 API (see API Versioning below), then referenced by media ID:

```ruby
payload = {
  text: "Check out this image!",
  media: {
    media_ids: ["MEDIA_ID"]
  }
}.to_json

response = x_client.post("tweets", payload)
```

## 5. Other API Methods

### GET — Retrieve Data

```ruby
# Get authenticated user info
user = x_client.get("users/me")
# => {"data"=>{"id"=>"...", "name"=>"...", "username"=>"..."}}

# Get user by username
user = x_client.get("users/by/username/sferik")

# Get a specific tweet
tweet = x_client.get("tweets/TWEET_ID")
```

### PUT — Update Data

```ruby
response = x_client.put("tweets/TWEET_ID", '{"text":"Updated text"}')
```

### DELETE — Remove Data

```ruby
# Delete a tweet
response = x_client.delete("tweets/TWEET_ID")
# => {"data"=>{"deleted"=>true}}
```

## 6. Error Handling

### Error Class Hierarchy

```
StandardError
  X::Error
    X::NetworkError
    X::ConnectionException
    X::TooManyRedirects
    X::HTTPError
      X::ClientError           # 4xx errors
        X::BadRequest          # 400
        X::Unauthorized        # 401
        X::Forbidden           # 403
        X::NotFound            # 404
        X::NotAcceptable       # 406
        X::Gone                # 410
        X::UnprocessableEntity # 422
        X::PayloadTooLarge     # 413
        X::InvalidMediaType    # 415
        X::TooManyRequests     # 429 (rate limit exceeded)
      X::ServerError           # 5xx errors
        X::InternalServerError # 500
        X::BadGateway          # 502
        X::ServiceUnavailable  # 503
        X::GatewayTimeout      # 504
```

### Basic Error Rescue Pattern

```ruby
begin
  response = x_client.post("tweets", '{"text":"Hello!"}')
rescue X::Unauthorized => e
  Rails.logger.error("X API: Invalid credentials — #{e.message}")
rescue X::Forbidden => e
  Rails.logger.error("X API: Forbidden (check app permissions) — #{e.message}")
rescue X::TooManyRequests => e
  Rails.logger.warn("X API: Rate limited. Reset in #{e.reset_in}s")
rescue X::ClientError => e
  Rails.logger.error("X API client error (#{e.code}): #{e.message}")
rescue X::ServerError => e
  Rails.logger.error("X API server error (#{e.code}): #{e.message}")
rescue X::Error => e
  Rails.logger.error("X API error: #{e.message}")
end
```

### Error Attributes

All `X::HTTPError` subclasses expose:

- `e.message` — Human-readable error description (parsed from JSON response body)
- `e.code` — HTTP status code (e.g., 429, 403)
- `e.response` — The underlying `Net::HTTPResponse` object

`X::TooManyRequests` additionally exposes:

- `e.rate_limit` — The most restrictive `X::RateLimit` object
- `e.rate_limits` — Array of all exhausted rate limits
- `e.reset_at` — `Time` object when the rate limit resets
- `e.reset_in` — Integer seconds until reset (alias: `e.retry_after`)

## 7. Rate Limit Handling

### Understanding Rate Limit Types

The gem tracks three rate limit types via response headers:

- `rate-limit` — Standard per-endpoint rate limit
- `app-limit-24hour` — 24-hour application-level limit
- `user-limit-24hour` — 24-hour user-level limit

### Retry Pattern with Exponential Backoff

```ruby
MAX_RETRIES = 3

def post_tweet(client, text)
  attempts = 0
  begin
    attempts += 1
    client.post("tweets", { text: text }.to_json)
  rescue X::TooManyRequests => e
    raise if attempts >= MAX_RETRIES

    wait_seconds = e.reset_in + 1
    Rails.logger.warn("Rate limited by X API. Waiting #{wait_seconds}s before retry (attempt #{attempts}/#{MAX_RETRIES})")
    sleep(wait_seconds)
    retry
  end
end
```

### Simple Rate Limit Sleep Pattern

```ruby
begin
  response = x_client.post("tweets", '{"text":"Hello!"}')
rescue X::TooManyRequests => e
  sleep(e.reset_in + 1)
  retry
end
```

### Checking Rate Limit Info

```ruby
begin
  response = x_client.post("tweets", '{"text":"Hello!"}')
rescue X::TooManyRequests => e
  rate_limit = e.rate_limit
  Rails.logger.info("Limit: #{rate_limit.limit}")
  Rails.logger.info("Remaining: #{rate_limit.remaining}")
  Rails.logger.info("Resets at: #{rate_limit.reset_at}")
  Rails.logger.info("Resets in: #{rate_limit.reset_in}s")
end
```

## 8. API Versioning

By default the client uses API v2. To access v1.1 endpoints (e.g., for media upload):

```ruby
v1_client = X::Client.new(
  base_url: "https://api.twitter.com/1.1/",
  api_key:             Rails.application.credentials.x[:api_key],
  api_key_secret:      Rails.application.credentials.x[:api_key_secret],
  access_token:        Rails.application.credentials.x[:access_token],
  access_token_secret: Rails.application.credentials.x[:access_token_secret]
)

# Use v1.1 endpoints
languages = v1_client.get("help/languages.json")
```

To access the Ads API:

```ruby
ads_client = X::Client.new(
  base_url: "https://ads-api.twitter.com/12/",
  **x_credentials
)
ads_client.get("accounts")
```

## 9. Custom Response Parsing

By default responses are parsed into Ruby `Hash` and `Array` objects. You can use custom classes:

```ruby
# Parse into OpenStruct for dot-notation access
response = x_client.get("users/me", object_class: OpenStruct)
response.data.username  # => "sferik"

# Use a custom Struct
Tweet = Struct.new(:id, :text, :edit_history_tweet_ids)
response = x_client.get("tweets/TWEET_ID", object_class: Tweet)

# Use Set instead of Array
response = v1_client.get("help/languages.json", array_class: Set)
```

## 10. Rails Service Object Pattern

A recommended pattern for wrapping X API calls in a Rails service:

```ruby
# app/services/x_api_service.rb
class XApiService
  MAX_RETRIES = 3

  def initialize
    @client = X::Client.new(
      api_key:             Rails.application.credentials.x[:api_key],
      api_key_secret:      Rails.application.credentials.x[:api_key_secret],
      access_token:        Rails.application.credentials.x[:access_token],
      access_token_secret: Rails.application.credentials.x[:access_token_secret]
    )
  end

  def post_tweet(text)
    with_retry do
      @client.post("tweets", { text: text }.to_json)
    end
  end

  def delete_tweet(tweet_id)
    with_retry do
      @client.delete("tweets/#{tweet_id}")
    end
  end

  private

  def with_retry(attempts: 0, &block)
    block.call
  rescue X::TooManyRequests => e
    raise if attempts >= MAX_RETRIES

    sleep(e.reset_in + 1)
    with_retry(attempts: attempts + 1, &block)
  rescue X::Unauthorized => e
    Rails.logger.error("X API authentication error: #{e.message}")
    raise
  rescue X::Forbidden => e
    Rails.logger.error("X API forbidden: #{e.message}")
    raise
  rescue X::ServerError => e
    raise if attempts >= MAX_RETRIES

    sleep(2 ** attempts)  # exponential backoff for server errors
    with_retry(attempts: attempts + 1, &block)
  end
end
```

Usage:

```ruby
service = XApiService.new
response = service.post_tweet("Hello from Rails!")
tweet_id = response["data"]["id"]
```

## 11. Thread Safety

The client is thread-safe and can be shared across threads (e.g., in a class-level variable or Rails initializer):

```ruby
# config/initializers/x_client.rb
X_CLIENT = X::Client.new(
  api_key:             Rails.application.credentials.x[:api_key],
  api_key_secret:      Rails.application.credentials.x[:api_key_secret],
  access_token:        Rails.application.credentials.x[:access_token],
  access_token_secret: Rails.application.credentials.x[:access_token_secret]
)
```

## Key Considerations

- **API v2 by default**: The gem targets the X API v2 endpoints (base URL `https://api.twitter.com/2/`). Use `base_url` to override.
- **JSON body required**: POST/PUT bodies must be JSON strings, not Ruby hashes. Use `.to_json`.
- **Error message parsing**: The gem automatically parses JSON error responses for human-readable messages. Error messages can come from array error objects, title/detail pairs, or single error fields.
- **No runtime dependencies**: The gem uses only Ruby's built-in `net/http` library.
- **OAuth 1.0a required for posting**: To post tweets on behalf of an account, you must use OAuth 1.0a (api_key + access_token credentials). Bearer token authentication is read-only.
- **X API free tier restrictions**: The free tier of the X API has very limited write access (typically 1 app per account, 500 tweets/month). Check your plan limits at developer.x.com.
