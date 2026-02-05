# GitHub OAuth API Integration Guide

This document provides comprehensive information for integrating with GitHub using OAuth Apps in a Rails application. This integration allows read-only access to repository information including commit history.

## Overview

GitHub OAuth Apps provide OAuth 2.0-based authentication for accessing GitHub resources on behalf of users. Unlike GitHub Apps, OAuth Apps use long-lived access tokens and have simpler permission models.

- **API Base URL**: `https://api.github.com`
- **OAuth Documentation**: https://docs.github.com/en/apps/oauth-apps
- **API Documentation**: https://docs.github.com/en/rest
- **App Registration**: https://github.com/settings/applications/new

## 1. Creating a GitHub OAuth App

### Registration Steps

1. Navigate to **GitHub Settings > Developer settings > OAuth apps**
2. Click **"New OAuth App"** (or "Register a new application" for first-time users)
3. Fill in the required fields:
   - **Application name**: Your app's display name
   - **Homepage URL**: Full URL to your application's website
   - **Application description** (optional): Description shown to users during authorization
   - **Authorization callback URL**: Single callback endpoint (e.g., `https://yourapp.com/auth/github/callback`)

4. Click **"Register application"**

### Post-Registration

After registration, you'll receive:
- **Client ID**: Public identifier for your OAuth app
- **Client Secret**: Secret key for token exchange (keep secure, never commit to source control)

### Important Limitations

- **Single Callback URL**: OAuth Apps can only have ONE callback URL (unlike GitHub Apps which support multiple)
- **Account Limits**: A user or organization can own up to 100 OAuth apps
- **Security Note**: Only use public information in your OAuth app configuration; avoid internal URLs or sensitive data

## 2. OAuth Authorization Flow

GitHub OAuth Apps use the standard OAuth 2.0 web application flow.

### Flow Overview

```
1. Redirect user to GitHub authorization page
2. User approves access
3. GitHub redirects back with authorization code
4. Exchange code for access token
5. Use access token to make API requests
```

### Step 1: Direct User to Authorization

**Endpoint**: `GET https://github.com/login/oauth/authorize`

**Required Parameters**:
- `client_id`: Your app's client ID (required)

**Recommended Parameters**:
- `redirect_uri`: Callback URL (strongly recommended, must match registration)
- `state`: Random CSRF protection token (strongly recommended)
- `scope`: Space-delimited permissions (e.g., `repo user:email`)

**Optional Parameters**:
- `allow_signup`: Whether to show signup option (default: `true`)
- `prompt`: Set to `select_account` to force account picker
- `code_challenge`: PKCE SHA-256 hash (43 characters, strongly recommended)
- `code_challenge_method`: Must be `S256` if using PKCE (strongly recommended)

**Example Authorization URL**:

```ruby
def authorization_url
  state = SecureRandom.hex(32)
  session[:github_oauth_state] = state

  params = {
    client_id: ENV['GITHUB_CLIENT_ID'],
    redirect_uri: ENV['GITHUB_REDIRECT_URI'],
    scope: 'repo user:email',
    state: state,
    allow_signup: false
  }

  "https://github.com/login/oauth/authorize?#{params.to_query}"
end
```

### Step 2: Handle Authorization Callback

GitHub redirects to your callback URL with:
- **Success**: `code` and `state` parameters
- **Denial**: `error=access_denied`

**Example Callback Handler**:

```ruby
def oauth_callback
  # Check for user denial
  if params[:error]
    redirect_to root_path, alert: "GitHub authorization denied"
    return
  end

  # Verify state to prevent CSRF attacks
  unless params[:state] == session[:github_oauth_state]
    redirect_to root_path, alert: "Invalid state parameter"
    return
  end

  # Exchange code for access token
  authorization_code = params[:code]
  # Proceed to Step 3...
end
```

### Step 3: Exchange Code for Access Token

**Endpoint**: `POST https://github.com/login/oauth/access_token`

**Required Parameters**:
- `client_id`: Your app's client ID
- `client_secret`: Your app's client secret
- `code`: The authorization code from Step 2
- `redirect_uri`: Must match the original redirect_uri (if provided)

**Optional Parameters**:
- `code_verifier`: PKCE parameter (required if `code_challenge` was used)

**Important**: Authorization codes expire after **10 minutes**.

**Request Headers**:
- `Accept: application/json` (to receive JSON response)

**Example Token Exchange**:

```ruby
def exchange_code_for_token(code)
  response = HTTParty.post(
    'https://github.com/login/oauth/access_token',
    headers: {
      'Accept' => 'application/json'
    },
    body: {
      client_id: ENV['GITHUB_CLIENT_ID'],
      client_secret: ENV['GITHUB_CLIENT_SECRET'],
      code: code,
      redirect_uri: ENV['GITHUB_REDIRECT_URI']
    }
  )

  # Response format:
  # {
  #   "access_token": "gho_16C7e42F292c6912E7710c838347Ae178B4a",
  #   "scope": "repo,user:email",
  #   "token_type": "bearer"
  # }

  JSON.parse(response.body)
end
```

**Alternative Authentication**: You can provide credentials via HTTP Basic Authorization (client_id as username, client_secret as password) instead of POST parameters.

### Step 4: Use Access Token

Include the access token in all API requests via the Authorization header:

```ruby
headers = {
  'Authorization' => "Bearer #{access_token}",
  'Accept' => 'application/vnd.github+json',
  'X-GitHub-Api-Version' => '2022-11-28'
}

response = HTTParty.get(
  'https://api.github.com/user/repos',
  headers: headers
)
```

**Alternative**: You can also use `token` instead of `Bearer`:
```ruby
'Authorization' => "token #{access_token}"
```

## 3. Available Scopes

GitHub OAuth Apps use scopes to define permissions. Request only the scopes you need.

### Repository Access Scopes

| Scope | Description | Access Level |
|-------|-------------|--------------|
| `repo` | Full access to public and private repositories | Read/Write |
| `repo:status` | Access to commit statuses | Read/Write |
| `repo_deployment` | Access to deployment statuses | Read/Write |
| `public_repo` | Access to public repositories only | Read/Write |
| `repo:invite` | Access to repository invitations | Read/Write |
| `security_events` | Access to code scanning API | Read/Write |

### Read-Only Repository Access

**Important**: GitHub OAuth Apps do not have dedicated read-only scopes for repository content. The scopes are primarily write-focused.

**For Read-Only Access to Private Repositories**:
- Use the `repo` scope (grants full access but you can limit your application's behavior to read-only operations)
- There is no "read-only repo" scope for OAuth Apps

**For Read-Only Access to Public Repositories**:
- Use the `public_repo` scope (still grants write access, but only to public repos)
- Alternatively, access public resources without authentication (rate-limited)

### User Scopes

| Scope | Description |
|-------|-------------|
| `user` | Full access to user profile data |
| `user:email` | Access to user email addresses |
| `user:follow` | Access to follow/unfollow users |
| `read:user` | Read-only access to user profile |

### Organization Scopes

| Scope | Description |
|-------|-------------|
| `read:org` | Read-only access to organization membership |
| `write:org` | Read/write access to organization membership |
| `admin:org` | Full control of organizations |

### Other Scopes

- `gist`: Create and access gists
- `notifications`: Access to notifications
- `read:packages`: Read access to packages
- `write:packages`: Write access to packages
- `delete:packages`: Delete packages
- `workflow`: Access to GitHub Actions workflows

### Scope Notes

- Scopes are **space-delimited** in authorization requests: `repo user:email read:org`
- The `repo` scope grants access to organization-owned resources including projects, invitations, team memberships, and webhooks
- Users can review and revoke authorizations at: `https://github.com/settings/connections/applications/:client_id`

## 4. Token Management

### Token Expiration

**Critical Difference from GitHub Apps**: OAuth App access tokens **do not expire** based on time.

- **No Time-Based Expiration**: OAuth App tokens remain valid indefinitely (unlike GitHub App tokens which expire after 8 hours)
- **No Refresh Tokens**: OAuth Apps do not use refresh tokens
- **Automatic Revocation**: GitHub will automatically revoke an OAuth token after **1 year of inactivity**

### When Tokens Become Invalid

OAuth App tokens can be revoked or become invalid when:

1. **User Revokes Access**: User manually revokes authorization
2. **Application Revokes**: OAuth app owner revokes the token
3. **Public Exposure**: Token is pushed to a public repository or public gist
4. **Token Limit**: A user/application/scope combination is limited to 10 tokens; creating an 11th token revokes the oldest
5. **Inactivity**: Token not used for 1 year
6. **Organization Policies**: Organization admin revokes third-party access

### Token Limits

- **10 tokens** maximum per user/application/scope combination
- **10 tokens per hour** creation rate limit
- Oldest tokens are automatically revoked when limit is exceeded

### Token Validation

**Security Best Practice**: Always revalidate the user's identity after receiving an access token.

```ruby
def validate_token(access_token)
  response = HTTParty.get(
    'https://api.github.com/user',
    headers: {
      'Authorization' => "Bearer #{access_token}",
      'Accept' => 'application/vnd.github+json'
    }
  )

  if response.code == 200
    JSON.parse(response.body)
  else
    nil # Token is invalid
  end
end
```

### Revoking Tokens

Users can revoke access at: `https://github.com/settings/connections/applications/:client_id`

**Important**: Revoking all permissions from an OAuth app deletes any SSH keys the application generated, including deploy keys.

## 5. GitHub REST API Usage

### Authentication

All authenticated API requests require the Authorization header:

```ruby
headers = {
  'Authorization' => "Bearer #{access_token}",
  'Accept' => 'application/vnd.github+json',
  'X-GitHub-Api-Version' => '2022-11-28'
}
```

**Recommended Headers**:
- `Authorization`: Bearer token for authentication
- `Accept`: API version acceptance header
- `X-GitHub-Api-Version`: Explicit API version (recommended: `2022-11-28`)

### Rate Limits

**Authenticated Requests**:
- **5,000 requests per hour** for OAuth Apps
- Rate limit applies per access token

**Unauthenticated Requests**:
- **60 requests per hour** per IP address

**Check Rate Limit Status**:

```ruby
response = HTTParty.get(
  'https://api.github.com/rate_limit',
  headers: headers
)
```

**Rate Limit Headers** (included in all responses):
- `X-RateLimit-Limit`: Maximum requests allowed per hour
- `X-RateLimit-Remaining`: Requests remaining in current window
- `X-RateLimit-Reset`: Unix timestamp when rate limit resets
- `X-RateLimit-Used`: Number of requests made in current window

### Error Handling

```ruby
def handle_github_response(response)
  case response.code
  when 200, 201
    JSON.parse(response.body)
  when 401
    raise GitHubAuthError, "Invalid or expired token"
  when 403
    # Could be rate limit or insufficient permissions
    if response.headers['X-RateLimit-Remaining'] == '0'
      raise GitHubRateLimitError, "Rate limit exceeded"
    else
      raise GitHubPermissionError, "Insufficient permissions"
    end
  when 404
    raise GitHubNotFoundError, "Resource not found"
  when 422
    raise GitHubValidationError, "Validation failed: #{response.body}"
  else
    raise GitHubError, "API error: #{response.code}"
  end
end
```

## 6. Listing Repositories

### Endpoint: List Repositories for Authenticated User

**HTTP Method**: `GET`
**Endpoint**: `/user/repos`
**Full URL**: `https://api.github.com/user/repos`

**Required Scope**: None for public repos, `repo` or `public_repo` for creating repos

### Query Parameters

| Parameter | Type | Description | Default |
|-----------|------|-------------|---------|
| `visibility` | string | Filter by `all`, `public`, or `private` | `all` |
| `affiliation` | string | Comma-separated list: `owner`, `collaborator`, `organization_member` | `owner,collaborator,organization_member` |
| `type` | string | Filter by: `all`, `owner`, `public`, `private`, `member` | `all` |
| `sort` | string | Sort by: `created`, `updated`, `pushed`, `full_name` | `full_name` |
| `direction` | string | Sort direction: `asc` or `desc` | `asc` when using `full_name`, else `desc` |
| `per_page` | integer | Results per page (1-100) | `30` |
| `page` | integer | Page number for pagination | `1` |

### Example Request

```ruby
def list_repositories(access_token, visibility: 'all', sort: 'updated', per_page: 100)
  response = HTTParty.get(
    'https://api.github.com/user/repos',
    headers: {
      'Authorization' => "Bearer #{access_token}",
      'Accept' => 'application/vnd.github+json',
      'X-GitHub-Api-Version' => '2022-11-28'
    },
    query: {
      visibility: visibility,
      sort: sort,
      direction: 'desc',
      per_page: per_page
    }
  )

  JSON.parse(response.body)
end
```

### Response Format

Returns an array of repository objects:

```json
[
  {
    "id": 1296269,
    "node_id": "MDEwOlJlcG9zaXRvcnkxMjk2MjY5",
    "name": "Hello-World",
    "full_name": "octocat/Hello-World",
    "private": false,
    "owner": {
      "login": "octocat",
      "id": 1,
      "avatar_url": "https://github.com/images/error/octocat_happy.gif",
      "type": "User"
    },
    "html_url": "https://github.com/octocat/Hello-World",
    "description": "This your first repo!",
    "url": "https://api.github.com/repos/octocat/Hello-World",
    "visibility": "public",
    "default_branch": "main",
    "created_at": "2011-01-26T19:01:12Z",
    "updated_at": "2011-01-26T19:14:43Z",
    "pushed_at": "2011-01-26T19:06:43Z"
  }
]
```

### Key Fields

- `name`: Repository name (without owner)
- `full_name`: Owner and repository name (`owner/repo`)
- `private`: Boolean indicating private vs public
- `visibility`: String value (`"public"` or `"private"`)
- `owner`: Owner information including `login` (username)
- `html_url`: Web URL to the repository
- `url`: API URL for the repository
- `default_branch`: Default branch name (usually `main` or `master`)

### Pagination

Use the `Link` header for pagination:

```ruby
def fetch_all_repositories(access_token)
  all_repos = []
  url = 'https://api.github.com/user/repos?per_page=100'

  while url
    response = HTTParty.get(
      url,
      headers: {
        'Authorization' => "Bearer #{access_token}",
        'Accept' => 'application/vnd.github+json',
        'X-GitHub-Api-Version' => '2022-11-28'
      }
    )

    all_repos += JSON.parse(response.body)

    # Parse Link header for next page
    link_header = response.headers['Link']
    url = parse_next_url(link_header)
  end

  all_repos
end

def parse_next_url(link_header)
  return nil unless link_header

  links = link_header.split(',').map do |link|
    url, rel = link.split(';').map(&:strip)
    [rel.match(/rel="(.+)"/)[1], url.match(/<(.+)>/)[1]]
  end.to_h

  links['next']
end
```

## 7. Listing Commits

### Endpoint: List Commits for a Repository

**HTTP Method**: `GET`
**Endpoint**: `/repos/{owner}/{repo}/commits`
**Full URL**: `https://api.github.com/repos/{owner}/{repo}/commits`

**Required Scope**: None for public repos, `repo` for private repos

### Path Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `owner` | string | Repository owner username (case-insensitive) |
| `repo` | string | Repository name without `.git` (case-insensitive) |

### Query Parameters

| Parameter | Type | Description | Default |
|-----------|------|-------------|---------|
| `sha` | string | Branch name or commit SHA to start from | Repository's default branch |
| `path` | string | Only commits affecting this file path | All commits |
| `author` | string | GitHub username or email address | All authors |
| `committer` | string | Committer username or email address | All committers |
| `since` | string | ISO 8601 timestamp (e.g., `2024-01-01T00:00:00Z`) | No limit |
| `until` | string | ISO 8601 timestamp | No limit |
| `per_page` | integer | Results per page (1-100) | `30` |
| `page` | integer | Page number | `1` |

### Example Request

```ruby
def list_commits(access_token, owner, repo, per_page: 10, since: nil)
  params = {
    per_page: per_page
  }
  params[:since] = since.iso8601 if since

  response = HTTParty.get(
    "https://api.github.com/repos/#{owner}/#{repo}/commits",
    headers: {
      'Authorization' => "Bearer #{access_token}",
      'Accept' => 'application/vnd.github+json',
      'X-GitHub-Api-Version' => '2022-11-28'
    },
    query: params
  )

  JSON.parse(response.body)
end
```

### Response Format

Returns an array of commit objects:

```json
[
  {
    "sha": "6dcb09b5b57875f334f61aebed695e2e4193db5e",
    "node_id": "MDY6Q29tbWl0NmRjYjA5YjViNTc4NzVmMzM0ZjYxYWViZWQ2OTVlMmU0MTkzZGI1ZQ==",
    "commit": {
      "author": {
        "name": "Monalisa Octocat",
        "email": "support@github.com",
        "date": "2011-04-14T16:00:49Z"
      },
      "committer": {
        "name": "Monalisa Octocat",
        "email": "support@github.com",
        "date": "2011-04-14T16:00:49Z"
      },
      "message": "Fix all the bugs",
      "tree": {
        "sha": "6dcb09b5b57875f334f61aebed695e2e4193db5e",
        "url": "https://api.github.com/repos/octocat/Hello-World/tree/6dcb09b5b57875f334f61aebed695e2e4193db5e"
      }
    },
    "url": "https://api.github.com/repos/octocat/Hello-World/commits/6dcb09b5b57875f334f61aebed695e2e4193db5e",
    "html_url": "https://github.com/octocat/Hello-World/commit/6dcb09b5b57875f334f61aebed695e2e4193db5e",
    "author": {
      "login": "octocat",
      "id": 1,
      "avatar_url": "https://github.com/images/error/octocat_happy.gif",
      "type": "User"
    },
    "committer": {
      "login": "octocat",
      "id": 1,
      "avatar_url": "https://github.com/images/error/octocat_happy.gif",
      "type": "User"
    },
    "parents": [
      {
        "sha": "7638417db6d59f3c431d3e1f261cc637155684cd",
        "url": "https://api.github.com/repos/octocat/Hello-World/commits/7638417db6d59f3c431d3e1f261cc637155684cd"
      }
    ]
  }
]
```

### Key Commit Fields

- `sha`: Unique commit hash
- `commit.message`: Commit message
- `commit.author`: Author information (name, email, date)
- `commit.committer`: Committer information
- `author`: GitHub user who authored (may be null if not a GitHub user)
- `committer`: GitHub user who committed
- `html_url`: Web URL to view the commit
- `parents`: Array of parent commits

### Fetching Recent Commits

```ruby
def get_recent_commits(access_token, owner, repo, limit: 10)
  response = HTTParty.get(
    "https://api.github.com/repos/#{owner}/#{repo}/commits",
    headers: {
      'Authorization' => "Bearer #{access_token}",
      'Accept' => 'application/vnd.github+json',
      'X-GitHub-Api-Version' => '2022-11-28'
    },
    query: {
      per_page: limit
    }
  )

  commits = JSON.parse(response.body)

  # Format for display
  commits.map do |commit|
    {
      sha: commit['sha'][0..7], # Short SHA
      message: commit['commit']['message'].lines.first.strip, # First line only
      author: commit['commit']['author']['name'],
      date: commit['commit']['author']['date'],
      url: commit['html_url']
    }
  end
end
```

## 8. Security Considerations

### PKCE (Proof Key for Code Exchange)

**Strongly Recommended** for enhanced security, especially for public clients:

```ruby
def generate_pkce_params
  # Generate code verifier (43-128 characters, URL-safe)
  code_verifier = SecureRandom.urlsafe_base64(96)

  # Generate code challenge (SHA-256 hash of verifier)
  code_challenge = Base64.urlsafe_encode64(
    Digest::SHA256.digest(code_verifier)
  ).tr('=', '')

  session[:github_code_verifier] = code_verifier

  {
    code_challenge: code_challenge,
    code_challenge_method: 'S256'
  }
end

# Include in authorization URL
pkce = generate_pkce_params
auth_url = "https://github.com/login/oauth/authorize?" +
  "client_id=#{client_id}" +
  "&code_challenge=#{pkce[:code_challenge]}" +
  "&code_challenge_method=S256"

# Include in token exchange
def exchange_with_pkce(code)
  HTTParty.post(
    'https://github.com/login/oauth/access_token',
    body: {
      client_id: ENV['GITHUB_CLIENT_ID'],
      client_secret: ENV['GITHUB_CLIENT_SECRET'],
      code: code,
      code_verifier: session[:github_code_verifier]
    }
  )
end
```

### State Parameter (CSRF Protection)

Always use a random state parameter:

```ruby
def authorize
  state = SecureRandom.hex(32)
  session[:github_oauth_state] = state

  redirect_to "https://github.com/login/oauth/authorize?" +
    "client_id=#{client_id}&state=#{state}",
    allow_other_host: true
end

def callback
  unless params[:state] == session[:github_oauth_state]
    redirect_to root_path, alert: "Invalid state"
    return
  end
  # Continue with token exchange...
end
```

### Redirect URI Validation

- Host and port must **exactly match** the registered callback URL
- For development, use `http://localhost:3000/callback` (localhost is allowed for development)
- For native apps, use loopback addresses: `http://127.0.0.1` or `http://[::1]` (not `localhost`)
- Production must use HTTPS

### Token Storage

- **Never commit tokens** to source control
- Store in **encrypted database columns**
- Use Rails credentials or environment variables for client secrets
- Clear tokens from session after storing securely

```ruby
# Good: Encrypted storage
class User < ApplicationRecord
  encrypts :github_access_token
end

# Bad: Plain text storage (DON'T DO THIS)
class User < ApplicationRecord
  # No encryption!
end
```

### Token Revalidation

Always verify the token and user identity after receiving it:

```ruby
def verify_and_store_token(token_response)
  access_token = token_response['access_token']

  # Verify token works and get user info
  user_info = validate_token(access_token)

  unless user_info
    raise GitHubAuthError, "Token validation failed"
  end

  # Store token and user info
  current_user.update!(
    github_access_token: access_token,
    github_username: user_info['login'],
    github_user_id: user_info['id']
  )
end
```

## 9. Device Flow (Alternative for CLI/Headless Apps)

For applications without a web browser (CLI tools, IoT devices), use the device flow.

### Step 1: Request Device Codes

```ruby
def request_device_code
  response = HTTParty.post(
    'https://github.com/login/device/code',
    body: {
      client_id: ENV['GITHUB_CLIENT_ID'],
      scope: 'repo'
    }
  )

  # Response:
  # {
  #   "device_code": "3584d83530557fdd1f46af8289938c8ef79f9dc5",
  #   "user_code": "WDJB-MJHT",
  #   "verification_uri": "https://github.com/login/device",
  #   "expires_in": 900,
  #   "interval": 5
  # }

  JSON.parse(response.body)
end
```

### Step 2: Display Code to User

```ruby
device_auth = request_device_code

puts "Go to: #{device_auth['verification_uri']}"
puts "Enter code: #{device_auth['user_code']}"
puts "Waiting for authorization..."
```

### Step 3: Poll for Authorization

```ruby
def poll_for_authorization(device_code, interval)
  loop do
    sleep(interval)

    response = HTTParty.post(
      'https://github.com/login/oauth/access_token',
      headers: { 'Accept' => 'application/json' },
      body: {
        client_id: ENV['GITHUB_CLIENT_ID'],
        device_code: device_code,
        grant_type: 'urn:ietf:params:oauth:grant-type:device_code'
      }
    )

    result = JSON.parse(response.body)

    case result['error']
    when 'authorization_pending'
      # Keep waiting
      next
    when 'slow_down'
      # Increase interval by 5 seconds
      interval += 5
      next
    when 'expired_token'
      raise GitHubDeviceAuthError, "Device code expired"
    when 'access_denied'
      raise GitHubDeviceAuthError, "User denied authorization"
    when nil
      # Success!
      return result['access_token']
    else
      raise GitHubDeviceAuthError, "Unknown error: #{result['error']}"
    end
  end
end
```

**Note**: Device flow must be enabled in your OAuth App settings.

## 10. Rails Integration Example

### Service Object

```ruby
class GitHubService
  BASE_URL = 'https://api.github.com'
  API_VERSION = '2022-11-28'

  def initialize(access_token)
    @access_token = access_token
  end

  def list_repositories(visibility: 'all', per_page: 100)
    get('/user/repos', {
      visibility: visibility,
      sort: 'updated',
      direction: 'desc',
      per_page: per_page
    })
  end

  def list_commits(owner, repo, limit: 10)
    get("/repos/#{owner}/#{repo}/commits", {
      per_page: limit
    })
  end

  def get_user
    get('/user')
  end

  private

  def get(path, params = {})
    response = HTTParty.get(
      "#{BASE_URL}#{path}",
      headers: headers,
      query: params
    )

    handle_response(response)
  end

  def headers
    {
      'Authorization' => "Bearer #{@access_token}",
      'Accept' => 'application/vnd.github+json',
      'X-GitHub-Api-Version' => API_VERSION
    }
  end

  def handle_response(response)
    case response.code
    when 200, 201
      JSON.parse(response.body)
    when 401
      raise GitHubAuthError, "Invalid or expired token"
    when 403
      if response.headers['X-RateLimit-Remaining'] == '0'
        raise GitHubRateLimitError, "Rate limit exceeded"
      else
        raise GitHubPermissionError, "Insufficient permissions"
      end
    when 404
      raise GitHubNotFoundError, "Resource not found"
    else
      raise GitHubError, "API error: #{response.code}"
    end
  end
end
```

### OAuth Controller

```ruby
class GitHubOauthController < ApplicationController
  def authorize
    session[:github_oauth_state] = SecureRandom.hex(32)
    redirect_to authorization_url, allow_other_host: true
  end

  def callback
    if params[:error]
      redirect_to root_path, alert: "GitHub authorization denied"
      return
    end

    unless params[:state] == session[:github_oauth_state]
      redirect_to root_path, alert: "Invalid state parameter"
      return
    end

    token_response = exchange_code(params[:code])
    access_token = token_response['access_token']

    # Verify token and get user info
    github_service = GitHubService.new(access_token)
    user_info = github_service.get_user

    # Store for the account (not the user)
    current_account.update!(
      github_access_token: access_token,
      github_username: user_info['login']
    )

    redirect_to settings_path, notice: "GitHub connected successfully"
  rescue => e
    Rails.logger.error("GitHub OAuth error: #{e.message}")
    redirect_to settings_path, alert: "Failed to connect GitHub"
  end

  def disconnect
    current_account.update!(
      github_access_token: nil,
      github_username: nil,
      github_repository: nil
    )

    redirect_to settings_path, notice: "GitHub disconnected"
  end

  private

  def authorization_url
    params = {
      client_id: Rails.application.credentials.github[:client_id],
      redirect_uri: github_callback_url,
      scope: 'repo',
      state: session[:github_oauth_state],
      allow_signup: false
    }

    "https://github.com/login/oauth/authorize?#{params.to_query}"
  end

  def exchange_code(code)
    response = HTTParty.post(
      'https://github.com/login/oauth/access_token',
      headers: { 'Accept' => 'application/json' },
      body: {
        client_id: Rails.application.credentials.github[:client_id],
        client_secret: Rails.application.credentials.github[:client_secret],
        code: code,
        redirect_uri: github_callback_url
      }
    )

    JSON.parse(response.body)
  end
end
```

### Routes

```ruby
# config/routes.rb
Rails.application.routes.draw do
  # GitHub OAuth
  get '/auth/github', to: 'github_oauth#authorize', as: :github_authorize
  get '/auth/github/callback', to: 'github_oauth#callback', as: :github_callback
  delete '/auth/github', to: 'github_oauth#disconnect', as: :github_disconnect
end
```

### Credentials

```yaml
# config/credentials.yml.enc (use: rails credentials:edit)
github:
  client_id: your_client_id_here
  client_secret: your_client_secret_here
```

### Model

```ruby
# app/models/account.rb
class Account < ApplicationRecord
  encrypts :github_access_token

  def github_connected?
    github_access_token.present?
  end

  def github_service
    return nil unless github_connected?
    @github_service ||= GitHubService.new(github_access_token)
  end

  def fetch_recent_commits(limit: 10)
    return [] unless github_repository.present?

    owner, repo = github_repository.split('/')
    github_service.list_commits(owner, repo, limit: limit)
  end
end
```

## 11. Important Considerations

### OAuth Apps vs GitHub Apps

**OAuth Apps**:
- Simpler setup and authorization flow
- Access tokens don't expire (but can be revoked)
- No refresh tokens needed
- Coarser permission model (fewer granular scopes)
- Act on behalf of a user
- Limited to 5,000 API requests per hour per token

**GitHub Apps**:
- More complex setup
- Fine-grained permissions
- Short-lived tokens (8 hours)
- Refresh tokens (6 months)
- Can act as an installation (not just a user)
- Higher rate limits possible

**For read-only repository access**, OAuth Apps are simpler and sufficient.

### Version Compatibility

- API Version: Recommend using `2022-11-28` (specify in `X-GitHub-Api-Version` header)
- OAuth flow: Stable and unchanged for years
- Monitor GitHub Changelog for deprecations: https://github.blog/changelog

### Privacy and Compliance

1. **User Consent**: Clearly explain what data you'll access during authorization
2. **Scope Minimization**: Only request the `repo` scope if you need it
3. **Data Storage**: Follow GDPR, CCPA, and applicable regulations
4. **Data Retention**: Implement appropriate retention policies
5. **User Rights**: Support token revocation and data deletion
6. **Transparency**: Provide clear privacy policy and terms

### Common Pitfalls

1. **Not handling token revocation**: Check token validity before each use
2. **Requesting too broad scopes**: Ask only for what you need
3. **Ignoring pagination**: Always handle paginated responses
4. **Hardcoding credentials**: Use Rails credentials or environment variables
5. **Not validating state**: Always verify the state parameter
6. **Rate limit ignorance**: Monitor and respect rate limits
7. **Single callback URL limitation**: Remember OAuth Apps only support one callback URL

### Testing

GitHub OAuth Apps don't have a dedicated sandbox, but you can:
- Create a separate OAuth App for development
- Use personal test repositories
- Mock the GitHub API in tests using VCR or WebMock
- Test with a real GitHub account in a staging environment

## 12. Summary Checklist

When implementing GitHub OAuth integration:

- [ ] Register OAuth App at https://github.com/settings/applications/new
- [ ] Store client ID and secret in Rails credentials (never commit to repo)
- [ ] Implement OAuth authorization flow with state parameter for CSRF protection
- [ ] Consider implementing PKCE for enhanced security
- [ ] Request minimal scopes needed (`repo` for private repo access)
- [ ] Validate tokens after receiving them
- [ ] Handle authorization denial gracefully
- [ ] Implement proper error handling for API requests
- [ ] Respect rate limits (5,000 requests per hour)
- [ ] Store tokens encrypted in database
- [ ] Provide user ability to disconnect/revoke access
- [ ] Handle pagination for API responses
- [ ] Test with real GitHub account before production
- [ ] Monitor for token revocation by users
- [ ] Implement logging for debugging OAuth flow

---

**Last Updated**: February 1, 2026
**API Version**: 2022-11-28
**Document Version**: 1.0

## Additional Resources

### Official Documentation
- [GitHub OAuth Apps Documentation](https://docs.github.com/en/apps/oauth-apps)
- [GitHub REST API Documentation](https://docs.github.com/en/rest)
- [OAuth App Authorization](https://docs.github.com/en/apps/oauth-apps/building-oauth-apps/authorizing-oauth-apps)
- [OAuth Scopes](https://docs.github.com/en/apps/oauth-apps/building-oauth-apps/scopes-for-oauth-apps)
- [Creating an OAuth App](https://docs.github.com/en/apps/oauth-apps/building-oauth-apps/creating-an-oauth-app)

### API References
- [Commits API](https://docs.github.com/en/rest/commits/commits)
- [Repositories API](https://docs.github.com/en/rest/repos/repos)
- [Rate Limiting](https://docs.github.com/en/rest/overview/rate-limits-for-the-rest-api)

### Community Resources
- [Octokit.rb](https://github.com/octokit/octokit.rb) - Official Ruby toolkit for GitHub API
- [GitHub Changelog](https://github.blog/changelog/) - API updates and changes
