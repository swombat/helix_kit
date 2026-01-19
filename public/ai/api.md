# Helix Kit API Documentation

## Authentication

All API requests require a Bearer token in the Authorization header:

```
Authorization: Bearer hx_your_api_key_here
```

### Getting an API Key

**Option 1: Browser** - Visit `/api_keys` while logged in to create keys manually.

**Option 2: OAuth-style CLI flow:**
```bash
# 1. Request authorization
curl -X POST https://your-domain/api/v1/key_requests \
  -d "client_name=Your App Name"

# Response:
{
  "request_token": "abc123...",
  "approval_url": "https://your-domain/api_keys/approve/abc123...",
  "poll_url": "https://your-domain/api/v1/key_requests/abc123...",
  "expires_at": "2026-01-15T20:17:32Z"
}

# 2. Open approval_url in browser, user clicks Approve

# 3. Poll for the key
curl https://your-domain/api/v1/key_requests/abc123...

# Response (after approval):
{
  "status": "approved",
  "api_key": "hx_...",
  "user_email": "user@example.com"
}
```

The API key is only returned once. Store it securely.

---

## Endpoints

### List Conversations

```
GET /api/v1/conversations
```

Returns up to 100 most recent conversations.

**Response:**
```json
{
  "conversations": [
    {
      "id": "abc123",
      "title": "Project Planning",
      "summary": "Discussed Q1 roadmap...",
      "summary_stale": false,
      "model": "GPT-5",
      "message_count": 24,
      "updated_at": "2026-01-15T10:30:00Z"
    }
  ]
}
```

| Field | Description |
|-------|-------------|
| `id` | Unique conversation identifier |
| `title` | Conversation title |
| `summary` | AI-generated summary (null if not yet generated) |
| `summary_stale` | true if summary needs refresh |
| `model` | AI model used |
| `message_count` | Total messages in conversation |
| `updated_at` | Last activity timestamp (ISO 8601) |

---

### Get Conversation Transcript

```
GET /api/v1/conversations/:id
```

Returns full conversation with message transcript.

**Response:**
```json
{
  "conversation": {
    "id": "abc123",
    "title": "Project Planning",
    "model": "GPT-5",
    "created_at": "2026-01-15T09:00:00Z",
    "updated_at": "2026-01-15T10:30:00Z",
    "transcript": [
      {
        "role": "user",
        "content": "Let's plan the Q1 roadmap",
        "author": "Daniel",
        "timestamp": "2026-01-15T09:00:00Z"
      },
      {
        "role": "assistant",
        "content": "I'd be happy to help...",
        "author": "GPT-5",
        "timestamp": "2026-01-15T09:00:15Z"
      }
    ]
  }
}
```

Note: Transcript excludes images, thinking traces, and tool calls for cleaner output.

---

### Post Message to Conversation

```
POST /api/v1/conversations/:id/create_message
Content-Type: application/json

{
  "content": "Your message here"
}
```

Posts a message as the authenticated user.

**Response:**
```json
{
  "message": {
    "id": "xyz789",
    "content": "Your message here",
    "created_at": "2026-01-15T10:31:00Z"
  },
  "ai_response_triggered": true
}
```

| Field | Description |
|-------|-------------|
| `ai_response_triggered` | true if AI will respond (1-1 chats only). Group chats require manual triggers. |

**Errors:**
- `422` - Conversation is archived or deleted

---

### List Whiteboards

```
GET /api/v1/whiteboards
```

Returns all active whiteboards.

**Response:**
```json
{
  "whiteboards": [
    {
      "id": "wb123",
      "name": "Meeting Notes",
      "summary": "Notes from team meetings",
      "content_length": 4500,
      "lock_version": 3
    }
  ]
}
```

---

### Create Whiteboard

```
POST /api/v1/whiteboards
Content-Type: application/json

{
  "name": "My New Whiteboard",
  "content": "# Initial content\n\nStart writing here...",
  "summary": "Optional short summary"
}
```

Creates a new whiteboard.

| Field | Required | Description |
|-------|----------|-------------|
| `name` | Yes | Whiteboard name (max 100 chars, must be unique) |
| `content` | No | Initial content (max 100,000 chars) |
| `summary` | No | Short summary (max 250 chars) |

**Response (success - 201):**
```json
{
  "whiteboard": {
    "id": "wb456",
    "name": "My New Whiteboard",
    "lock_version": 0
  }
}
```

**Response (validation error - 422):**
```json
{
  "error": "Name has already been taken"
}
```

---

### Get Whiteboard

```
GET /api/v1/whiteboards/:id
```

**Response:**
```json
{
  "whiteboard": {
    "id": "wb123",
    "name": "Meeting Notes",
    "content": "# Meeting Notes\n\n...",
    "summary": "Notes from team meetings",
    "lock_version": 3,
    "last_edited_at": "2026-01-15T10:00:00Z",
    "editor_name": "Daniel"
  }
}
```

---

### Update Whiteboard

```
PATCH /api/v1/whiteboards/:id
Content-Type: application/json

{
  "content": "# Updated content\n\n...",
  "lock_version": 3
}
```

Replaces whiteboard content. Uses optimistic locking to prevent conflicts.

**Response (success):**
```json
{
  "whiteboard": {
    "id": "wb123",
    "lock_version": 4
  }
}
```

**Response (conflict - 409):**
```json
{
  "error": "Whiteboard was modified by another user"
}
```

Always include `lock_version` from your last read to detect concurrent edits.

---

## Error Responses

All errors return JSON with an `error` field:

| Status | Meaning |
|--------|---------|
| `401` | Invalid or missing API key |
| `404` | Resource not found |
| `409` | Conflict (optimistic locking) |
| `422` | Unprocessable (validation error) |

```json
{
  "error": "Invalid or missing API key"
}
```

---

## Rate Limits

No rate limits currently enforced.

---

## Example: Claude Code Integration

```bash
# List recent conversations
curl -H "Authorization: Bearer $HELIX_API_KEY" \
  https://your-domain/api/v1/conversations

# Read a specific conversation
curl -H "Authorization: Bearer $HELIX_API_KEY" \
  https://your-domain/api/v1/conversations/abc123

# Post a message
curl -X POST \
  -H "Authorization: Bearer $HELIX_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"content":"Hello from Claude Code!"}' \
  https://your-domain/api/v1/conversations/abc123/create_message

# Create a whiteboard
curl -X POST \
  -H "Authorization: Bearer $HELIX_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"name":"My Notes", "content":"# Notes\n\nStarting fresh."}' \
  https://your-domain/api/v1/whiteboards

# Update a whiteboard
curl -X PATCH \
  -H "Authorization: Bearer $HELIX_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"content":"# New content", "lock_version": 3}' \
  https://your-domain/api/v1/whiteboards/wb123
```
