# Oura Ring API Integration Guide

This document provides comprehensive information for integrating with the Oura Ring API v2 in a Rails application.

## Overview

The Oura Ring API provides access to health and wellness data from Oura Ring devices, including sleep, activity, readiness, heart rate, and other biometric measurements. The API uses OAuth 2.0 for authentication and provides RESTful endpoints for accessing user data.

- **API Version**: v2 (v1 was removed January 22, 2024)
- **Base URL**: `https://api.ouraring.com/v2`
- **Documentation**: https://cloud.ouraring.com/v2/docs
- **OAuth Portal**: https://cloud.ouraring.com (for app registration)

## 1. OAuth 2.0 Authentication Flow

### Authentication Overview

Oura supports two authentication methods:

1. **Personal Access Token**: For accessing your own data only. Users generate tokens through their account settings. *Note: Being deprecated by end of 2025.*
2. **OAuth2 Application**: For multi-user access (recommended for production). Requires application registration.

### OAuth Endpoints

```
Authorization URL: https://cloud.ouraring.com/oauth/authorize
Access Token URL: https://api.ouraring.com/oauth/token
Revoke Token URL: https://api.ouraring.com/oauth/revoke?access_token={access_token}
```

### Available Scopes

Request specific scopes during authorization. Users can enable/disable scopes during the authorization flow.

| Scope | Description |
|-------|-------------|
| `email` | User's email address |
| `personal` | Demographics (gender, age, height, weight) |
| `daily` | Sleep, activity, and readiness summaries |
| `heartrate` | Time series heart rate data (Gen 3 only) |
| `workout` | Auto-detected and user-entered workout summaries |
| `tag` | User-created tags |
| `session` | Guided and unguided app sessions |
| `spo2` | Daily SpO2 average during sleep |

### Server-Side OAuth Flow (Recommended)

#### Step 1: Direct User to Authorization

```ruby
# Generate authorization URL
def authorization_url
  params = {
    response_type: 'code',
    client_id: ENV['OURA_CLIENT_ID'],
    redirect_uri: ENV['OURA_REDIRECT_URI'],
    scope: 'email personal daily heartrate workout',
    state: SecureRandom.hex(32) # CSRF protection
  }

  "https://cloud.ouraring.com/oauth/authorize?#{params.to_query}"
end
```

**Parameters:**
- `response_type`: Must be `code`
- `client_id`: Your application's client ID (required)
- `redirect_uri`: Where to redirect after authorization (optional, must match registration)
- `scope`: Space-separated list of scopes (optional, defaults to all)
- `state`: CSRF token for security (optional but recommended)

#### Step 2: Handle Authorization Callback

Oura redirects back to your `redirect_uri` with:
- **Success**: `code`, `scope`, and `state` parameters
- **Denial**: `error=access_denied`

```ruby
def oauth_callback
  if params[:error]
    # User denied access
    redirect_to root_path, alert: "Authorization denied"
    return
  end

  # Verify state matches to prevent CSRF
  unless valid_state?(params[:state])
    redirect_to root_path, alert: "Invalid state"
    return
  end

  # Exchange code for tokens
  authorization_code = params[:code]
  # Proceed to Step 3...
end
```

#### Step 3: Exchange Code for Access Token

```ruby
def exchange_code_for_token(code)
  response = HTTParty.post(
    'https://api.ouraring.com/oauth/token',
    body: {
      grant_type: 'authorization_code',
      code: code,
      client_id: ENV['OURA_CLIENT_ID'],
      client_secret: ENV['OURA_CLIENT_SECRET'],
      redirect_uri: ENV['OURA_REDIRECT_URI']
    }
  )

  # Response includes:
  # {
  #   "access_token": "...",
  #   "refresh_token": "...",
  #   "expires_in": 2592000,  # 30 days in seconds
  #   "token_type": "bearer"
  # }

  JSON.parse(response.body)
end
```

**Parameters:**
- `grant_type`: Must be `authorization_code`
- `code`: The authorization code from Step 2 (required)
- `client_id`: Your application's client ID (required)
- `client_secret`: Your application's client secret (required)
- `redirect_uri`: Must match authorization request (optional)

**Alternative Authentication Method:**
Credentials can be provided via HTTP Basic Authorization (client_id as username, client_secret as password) instead of POST parameters.

#### Step 4: Refresh Expired Tokens

Access tokens expire after 30 days. Use the refresh token to obtain a new access token:

```ruby
def refresh_access_token(refresh_token)
  response = HTTParty.post(
    'https://api.ouraring.com/oauth/token',
    body: {
      grant_type: 'refresh_token',
      refresh_token: refresh_token,
      client_id: ENV['OURA_CLIENT_ID'],
      client_secret: ENV['OURA_CLIENT_SECRET']
    }
  )

  # Returns new access_token AND new refresh_token
  JSON.parse(response.body)
end
```

**Important**: Both the access token AND refresh token are refreshed. Store the new refresh token for future use.

### Using Access Tokens

Include the access token in all API requests via the Authorization header:

```ruby
headers = {
  'Authorization' => "Bearer #{access_token}"
}
```

**Note**: V2 API requires header-based authentication. Query parameter authentication was removed for security.

### Client-Side Only Flow

Uses `response_type=token` instead of `code`. **Not recommended** because:
- Does not support refresh tokens
- Tokens expire after 30 days with no way to refresh
- User must re-authenticate when token expires

### Revoking Tokens

```ruby
def revoke_token(access_token)
  HTTParty.get("https://api.ouraring.com/oauth/revoke?access_token=#{access_token}")
end
```

### Application Limits

- By default, API applications have a **10 user limit**
- For wider release, your application must be approved by Oura
- Contact Oura to discuss approval for higher limits

## 2. Available API Endpoints

All endpoints use the base URL `https://api.ouraring.com/v2` and require Bearer token authentication.

### User Collection Endpoints

| Endpoint | Description | Scope Required |
|----------|-------------|----------------|
| `/usercollection/personal_info` | User demographics | `personal` |
| `/usercollection/daily_sleep` | Daily sleep summaries | `daily` |
| `/usercollection/daily_activity` | Daily activity summaries | `daily` |
| `/usercollection/daily_readiness` | Daily readiness summaries | `daily` |
| `/usercollection/daily_spo2` | Daily SpO2 averages | `spo2` |
| `/usercollection/heartrate` | Time-series heart rate data | `heartrate` |
| `/usercollection/workout` | Workout summaries | `workout` |
| `/usercollection/session` | Guided/unguided sessions | `session` |
| `/usercollection/tag` | User-created tags | `tag` |
| `/usercollection/enhanced_tag` | Enhanced tag data | `tag` |
| `/usercollection/daily_resilience` | Resilience scores | `daily` |
| `/usercollection/daily_cardiovascular_age` | Cardiovascular age | `daily` |
| `/usercollection/vo2_max` | VO2 Max measurements | `daily` |
| `/usercollection/daily_stress` | Stress measurements | `daily` |
| `/usercollection/rest_mode_period` | Rest mode periods | `daily` |
| `/usercollection/ring_configuration` | Ring settings | `personal` |

### Common Query Parameters

Most endpoints support date range filtering:

```ruby
params = {
  start_date: '2024-01-01',  # YYYY-MM-DD format
  end_date: '2024-01-31',    # YYYY-MM-DD format
  next_token: 'abc123'       # For pagination
}
```

### Example API Request

```ruby
def get_daily_sleep(access_token, start_date, end_date)
  response = HTTParty.get(
    'https://api.ouraring.com/v2/usercollection/daily_sleep',
    headers: {
      'Authorization' => "Bearer #{access_token}"
    },
    query: {
      start_date: start_date,
      end_date: end_date
    }
  )

  JSON.parse(response.body)
end
```

## 3. Data Structures

### Response Format

All endpoints return JSON with this structure:

```json
{
  "data": [...],
  "next_token": "abc123"
}
```

- `data`: Array of objects containing the requested data
- `next_token`: Token for retrieving the next page (null when no more pages)

### Daily Sleep

```json
{
  "id": "8f9a5221-639e-4a85-81cb-4065ef23f979",
  "contributors": {
    "deep_sleep": 57,
    "efficiency": 98,
    "latency": 81,
    "rem_sleep": 20,
    "restfulness": 54,
    "timing": 84,
    "total_sleep": 60
  },
  "day": "2022-07-14",
  "score": 63,
  "timestamp": "2022-07-14T00:00:00+00:00"
}
```

**Fields:**
- `id`: Unique identifier for the sleep record
- `score`: Overall sleep score (0-100)
- `day`: Date of the sleep session (YYYY-MM-DD)
- `timestamp`: ISO 8601 timestamp with timezone
- `contributors`: Breakdown of factors contributing to sleep score
  - `deep_sleep`: Deep sleep contribution (0-100)
  - `efficiency`: Sleep efficiency contribution (0-100)
  - `latency`: Sleep onset latency contribution (0-100)
  - `rem_sleep`: REM sleep contribution (0-100)
  - `restfulness`: Restfulness contribution (0-100)
  - `timing`: Sleep timing contribution (0-100)
  - `total_sleep`: Total sleep time contribution (0-100)

### Daily Readiness

```json
{
  "id": "8f9a5221-639e-4a85-81cb-4065ef23f979",
  "contributors": {
    "activity_balance": 56,
    "body_temperature": 98,
    "hrv_balance": 75,
    "previous_day_activity": null,
    "previous_night": 35,
    "recovery_index": 47,
    "resting_heart_rate": 94,
    "sleep_balance": 73
  },
  "day": "2021-10-27",
  "score": 66,
  "temperature_deviation": -0.2,
  "temperature_trend_deviation": 0.1,
  "timestamp": "2021-10-27T00:00:00+00:00"
}
```

**Fields:**
- `score`: Overall readiness score (0-100)
- `temperature_deviation`: Current temperature deviation from baseline (°C)
- `temperature_trend_deviation`: Temperature trend deviation (°C)
- `contributors`: Factors contributing to readiness
  - `activity_balance`: Recent activity balance (0-100)
  - `body_temperature`: Body temperature contribution (0-100)
  - `hrv_balance`: Heart rate variability balance (0-100)
  - `previous_day_activity`: Previous day's activity impact (0-100 or null)
  - `previous_night`: Previous night's sleep impact (0-100)
  - `recovery_index`: Recovery status (0-100)
  - `resting_heart_rate`: Resting heart rate contribution (0-100)
  - `sleep_balance`: Recent sleep balance (0-100)

### Daily Activity

```json
{
  "id": "8f9a5221-639e-4a85-81cb-4065ef23f979",
  "score": 82,
  "active_calories": 1222,
  "average_met_minutes": 1.40625,
  "contributors": {
    "meet_daily_targets": 43,
    "move_every_hour": 100,
    "recovery_time": 100,
    "stay_active": 98,
    "training_frequency": 71,
    "training_volume": 98
  },
  "equivalent_walking_distance": 24384,
  "high_activity_met_minutes": 444,
  "high_activity_time": 3000,
  "inactivity_alerts": 0,
  "low_activity_met_minutes": 117,
  "low_activity_time": 10020,
  "medium_activity_met_minutes": 391,
  "medium_activity_time": 6060,
  "met": {
    "interval": 60,
    "items": [0.1, 0.9, 1.2, ...]
  },
  "meters_to_target": -16616,
  "non_wear_time": 39780,
  "resting_time": 17100,
  "sedentary_met_minutes": 23,
  "sedentary_time": 18660,
  "steps": 18430,
  "target_calories": 350,
  "target_meters": 7500,
  "total_calories": 3446,
  "day": "2021-11-26",
  "timestamp": "2021-11-26T04:00:00.000-08:00"
}
```

**Key Fields:**
- `steps`: Total steps for the day
- `active_calories`: Calories burned through activity
- `total_calories`: Total daily calorie expenditure
- `met`: Metabolic Equivalent data
  - `interval`: Measurement interval in seconds (60)
  - `items`: Array of MET values over time
- Activity time breakdowns (in seconds):
  - `high_activity_time`: High intensity activity
  - `medium_activity_time`: Medium intensity activity
  - `low_activity_time`: Low intensity activity
  - `sedentary_time`: Sedentary time
  - `resting_time`: Rest time

### Heart Rate

```json
{
  "bpm": 58,
  "source": "awake",
  "timestamp": "2023-01-06T16:40:38+00:00"
}
```

**Fields:**
- `bpm`: Heart rate in beats per minute
- `source`: Context of measurement (`awake`, `workout`, `sleep`, etc.)
- `timestamp`: ISO 8601 timestamp with timezone

**Note**: Heart rate returns time-series data, potentially hundreds of readings per day.

### Personal Info

```json
{
  "id": "user-id",
  "age": 31,
  "weight": 74.8,
  "height": 1.8,
  "biological_sex": "male",
  "email": "user@example.com"
}
```

## 4. Pagination

The Oura API uses token-based pagination for large datasets.

### Pagination Response Structure

```json
{
  "data": [...],
  "next_token": "abc123"
}
```

### Handling Pagination

```ruby
def fetch_all_sleep_data(access_token, start_date, end_date)
  all_data = []
  next_token = nil

  loop do
    params = {
      start_date: start_date,
      end_date: end_date
    }
    params[:next_token] = next_token if next_token

    response = HTTParty.get(
      'https://api.ouraring.com/v2/usercollection/daily_sleep',
      headers: { 'Authorization' => "Bearer #{access_token}" },
      query: params
    )

    result = JSON.parse(response.body)
    all_data += result['data']

    next_token = result['next_token']
    break if next_token.nil?
  end

  all_data
end
```

**Important**: Always check for `next_token` in the response. When `next_token` is `null`, there are no more pages.

## 5. Rate Limits

### Current Limits

- **5,000 requests per 5-minute period**
- Approximately **1,000 requests per minute** on average

### Rate Limit Headers

Check response headers for rate limit information:
- `X-RateLimit-Limit`: Maximum requests allowed
- `X-RateLimit-Remaining`: Requests remaining in current window
- `X-RateLimit-Reset`: Timestamp when the rate limit resets

### Handling Rate Limits

```ruby
def make_oura_request(url, access_token)
  response = HTTParty.get(
    url,
    headers: { 'Authorization' => "Bearer #{access_token}" }
  )

  if response.code == 429
    # Rate limit exceeded
    retry_after = response.headers['Retry-After']&.to_i || 60
    sleep(retry_after)
    return make_oura_request(url, access_token)
  end

  response
end
```

### Best Practices

1. **Implement exponential backoff** for rate limit responses
2. **Cache responses** when appropriate to reduce API calls
3. **Batch requests** during off-peak hours if fetching historical data
4. **Monitor rate limit headers** to stay within limits
5. **Contact Oura** if you need higher rate limits for your application

## 6. Webhooks

### Overview

Oura API v2 supports webhooks for near real-time data updates, eliminating the need for polling.

**Webhook Features:**
- Near real-time notifications when new data is available
- More efficient than polling
- Reduces API call volume
- Recommended approach for getting latest data

### Webhook Endpoints

The API provides full webhook subscription management:

- **List subscriptions**: GET `/v2/webhook/subscription`
- **Create subscription**: POST `/v2/webhook/subscription`
- **Update subscription**: PUT `/v2/webhook/subscription/{id}`
- **Delete subscription**: DELETE `/v2/webhook/subscription/{id}`
- **Renew subscription**: POST `/v2/webhook/subscription/{id}/renew`

### Creating a Webhook Subscription

```ruby
def create_webhook_subscription(access_token, callback_url, event_type)
  response = HTTParty.post(
    'https://api.ouraring.com/v2/webhook/subscription',
    headers: {
      'Authorization' => "Bearer #{access_token}",
      'Content-Type' => 'application/json'
    },
    body: {
      callback_url: callback_url,
      event_type: event_type,
      verification_token: SecureRandom.hex(32)
    }.to_json
  )

  JSON.parse(response.body)
end
```

### Webhook Event Types

Available event types include:
- `create.daily_sleep`
- `create.daily_activity`
- `create.daily_readiness`
- `create.workout`
- `create.session`
- And others for different data types

### Webhook Payload Format

When new data is available, Oura sends a POST request to your callback URL:

```json
{
  "event_type": "create.daily_sleep",
  "user_id": "user-id",
  "data_type": "daily_sleep",
  "timestamp": "2024-01-27T12:00:00Z"
}
```

### Webhook Security

1. **Verification Token**: Include a secret token in your subscription
2. **HTTPS Required**: Callback URLs must use HTTPS
3. **Validate Payload**: Verify the request came from Oura
4. **Respond Quickly**: Return 200 OK within timeout period

### Webhook Response Handling

```ruby
class OuraWebhooksController < ApplicationController
  skip_before_action :verify_authenticity_token

  def receive
    # Verify the webhook is from Oura
    unless valid_webhook?(request)
      head :unauthorized
      return
    end

    payload = JSON.parse(request.body.read)

    # Process webhook asynchronously
    OuraWebhookJob.perform_later(payload)

    # Respond immediately
    head :ok
  end

  private

  def valid_webhook?(request)
    # Implement verification logic
    # Check signature, verification token, etc.
  end
end
```

### Data Timing

- Oura sends webhook notifications **within minutes** after a user syncs their ring
- Data is available via API immediately after webhook notification
- Use the webhook as a trigger to fetch the actual data from the API

### Webhook vs Polling

**Webhooks (Recommended):**
- Near real-time updates
- Reduces API calls and rate limit usage
- More efficient
- Lower latency

**Polling:**
- Simpler to implement initially
- Works without webhook infrastructure
- Higher API call volume
- Delayed data updates

## 7. Important Considerations

### Version Compatibility

- **V1 API**: Removed January 22, 2024
- **V2 API**: Current and actively maintained
- **Personal Access Tokens**: Being deprecated end of 2025
- **OAuth2**: Recommended for all new integrations

### Device Compatibility

- **Gen 3 Ring**: Full feature support including daytime heart rate
- **Gen 2 Ring**: Limited features (no daytime heart rate)
- **Gen 4 Ring**: Check latest documentation for new features

### Data Availability

- Data becomes available after user syncs their ring with the Oura app
- Sync typically happens automatically when in Bluetooth range of phone
- Manual sync available in the app
- Historical data available back to ring purchase date

### Data Quality

- Missing data: Gaps can occur if ring wasn't worn or synced
- Null values: Some contributor scores may be null if insufficient data
- Ring removal: Long periods of non-wear affect data completeness
- Check `non_wear_time` field for activity data

### Privacy and Compliance

1. **User Consent**: Obtain explicit consent before accessing data
2. **Data Storage**: Follow GDPR, HIPAA, and other regulations
3. **Data Retention**: Implement appropriate retention policies
4. **User Rights**: Support data deletion and export requests
5. **Scope Limitations**: Only request scopes you need

### Error Handling

```ruby
def handle_oura_response(response)
  case response.code
  when 200
    JSON.parse(response.body)
  when 401
    # Unauthorized - token expired or invalid
    raise OuraTokenError, "Access token expired or invalid"
  when 403
    # Forbidden - insufficient scope
    raise OuraScopeError, "Insufficient scope for this endpoint"
  when 429
    # Rate limit exceeded
    raise OuraRateLimitError, "Rate limit exceeded"
  when 500..599
    # Server error
    raise OuraServerError, "Oura API server error"
  else
    raise OuraError, "Unexpected response: #{response.code}"
  end
end
```

### Testing

Oura provides a **sandbox environment** for testing:
- Test OAuth flow without real user accounts
- Generate sample data for development
- Verify integration before production deployment
- Check third-party libraries for sandbox support

### Performance Tips

1. **Cache data locally**: Don't fetch the same data repeatedly
2. **Use webhooks**: More efficient than polling
3. **Batch historical requests**: Fetch larger date ranges in single requests
4. **Index by date**: Use date-based queries for efficient retrieval
5. **Async processing**: Handle webhook data in background jobs

### Common Pitfalls

1. **Not handling token refresh**: Implement automatic token refresh before expiry
2. **Ignoring pagination**: Always check for `next_token` and fetch all pages
3. **Over-polling**: Use webhooks instead of frequent polling
4. **Hardcoded credentials**: Use environment variables or Rails credentials
5. **Not handling null values**: Check for null in contributor scores
6. **Timezone issues**: All timestamps are in ISO 8601 with timezone info

## 8. Rails Integration Example

### Basic Service Object

```ruby
class OuraService
  BASE_URL = 'https://api.ouraring.com/v2'

  def initialize(access_token)
    @access_token = access_token
  end

  def daily_sleep(start_date:, end_date:)
    fetch_paginated('/usercollection/daily_sleep', start_date: start_date, end_date: end_date)
  end

  def daily_activity(start_date:, end_date:)
    fetch_paginated('/usercollection/daily_activity', start_date: start_date, end_date: end_date)
  end

  def daily_readiness(start_date:, end_date:)
    fetch_paginated('/usercollection/daily_readiness', start_date: start_date, end_date: end_date)
  end

  def heart_rate(start_date:, end_date:)
    fetch_paginated('/usercollection/heartrate', start_date: start_date, end_date: end_date)
  end

  private

  def fetch_paginated(endpoint, params = {})
    all_data = []
    next_token = nil

    loop do
      query_params = params.dup
      query_params[:next_token] = next_token if next_token

      response = HTTParty.get(
        "#{BASE_URL}#{endpoint}",
        headers: headers,
        query: query_params
      )

      raise_on_error(response)

      result = JSON.parse(response.body)
      all_data += result['data']

      next_token = result['next_token']
      break if next_token.nil?
    end

    all_data
  end

  def headers
    {
      'Authorization' => "Bearer #{@access_token}",
      'Content-Type' => 'application/json'
    }
  end

  def raise_on_error(response)
    return if response.success?

    case response.code
    when 401
      raise OuraTokenError, "Invalid or expired token"
    when 429
      raise OuraRateLimitError, "Rate limit exceeded"
    else
      raise OuraError, "API error: #{response.code}"
    end
  end
end
```

### OAuth Controller

```ruby
class OuraOauthController < ApplicationController
  def authorize
    session[:oauth_state] = SecureRandom.hex(32)
    redirect_to authorization_url, allow_other_host: true
  end

  def callback
    if params[:error]
      redirect_to root_path, alert: "Authorization denied"
      return
    end

    unless params[:state] == session[:oauth_state]
      redirect_to root_path, alert: "Invalid state"
      return
    end

    token_response = exchange_code(params[:code])

    current_user.update!(
      oura_access_token: token_response['access_token'],
      oura_refresh_token: token_response['refresh_token'],
      oura_token_expires_at: Time.current + token_response['expires_in'].seconds
    )

    redirect_to settings_path, notice: "Oura connected successfully"
  end

  private

  def authorization_url
    params = {
      response_type: 'code',
      client_id: Rails.application.credentials.oura[:client_id],
      redirect_uri: oura_callback_url,
      scope: 'email personal daily heartrate workout session',
      state: session[:oauth_state]
    }

    "https://cloud.ouraring.com/oauth/authorize?#{params.to_query}"
  end

  def exchange_code(code)
    response = HTTParty.post(
      'https://api.ouraring.com/oauth/token',
      body: {
        grant_type: 'authorization_code',
        code: code,
        client_id: Rails.application.credentials.oura[:client_id],
        client_secret: Rails.application.credentials.oura[:client_secret],
        redirect_uri: oura_callback_url
      }
    )

    JSON.parse(response.body)
  end
end
```

### Token Refresh Job

```ruby
class RefreshOuraTokenJob < ApplicationJob
  queue_as :default

  def perform(user_id)
    user = User.find(user_id)

    response = HTTParty.post(
      'https://api.ouraring.com/oauth/token',
      body: {
        grant_type: 'refresh_token',
        refresh_token: user.oura_refresh_token,
        client_id: Rails.application.credentials.oura[:client_id],
        client_secret: Rails.application.credentials.oura[:client_secret]
      }
    )

    result = JSON.parse(response.body)

    user.update!(
      oura_access_token: result['access_token'],
      oura_refresh_token: result['refresh_token'],
      oura_token_expires_at: Time.current + result['expires_in'].seconds
    )
  end
end
```

## 9. Additional Resources

### Official Documentation
- [Oura API v2 Documentation](https://cloud.ouraring.com/v2/docs)
- [OAuth Authentication Guide](https://cloud.ouraring.com/docs/authentication)
- [Oura API Support](https://support.ouraring.com/hc/en-us/articles/4415266939155-The-Oura-API)

### Third-Party Libraries
- [@pinta365/oura-api](https://jsr.io/@pinta365/oura-api) - TypeScript/JavaScript
- [oura-ring](https://pypi.org/project/oura-ring/) - Python
- [ouraring gem](https://github.com/hedgertronic/oura-ring) - Ruby

### Developer Resources
- [Oura Partner Portal](https://partnersupport.ouraring.com/)
- [API V2 Upgrade Guide](https://partnersupport.ouraring.com/hc/en-us/articles/19907726838163-Oura-API-V2-Upgrade-Guide)

### Community Integrations
- [Terra API Integration](https://tryterra.co/integrations/oura) - Unified health API
- [Home Assistant Integration](https://community.home-assistant.io/t/oura-ring-v2-custom-integration-track-your-sleep-readiness-activity-in-home-assistant/944424)

## 10. Summary Checklist

When implementing Oura API integration:

- [ ] Register OAuth application at cloud.ouraring.com
- [ ] Store client ID and secret in Rails credentials
- [ ] Implement OAuth authorization flow with CSRF protection
- [ ] Handle token refresh before 30-day expiration
- [ ] Request only the scopes you need
- [ ] Implement pagination for all data endpoints
- [ ] Respect rate limits (5,000 requests per 5 minutes)
- [ ] Set up webhook subscriptions for real-time updates
- [ ] Handle null values in API responses
- [ ] Implement proper error handling for all responses
- [ ] Store tokens securely (encrypted at rest)
- [ ] Provide user data deletion and export functionality
- [ ] Test with sandbox environment before production
- [ ] Monitor API usage and stay within limits
- [ ] Plan for Personal Access Token deprecation (end of 2025)

---

**Last Updated**: January 27, 2026
**API Version**: v2
**Document Version**: 1.0
