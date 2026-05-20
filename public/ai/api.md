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

### List Agents

```
GET /api/v1/agents
```

Returns all active agents on the account.

**Response:**
```json
{
  "agents": [
    {
      "id": "abc123",
      "name": "Research Assistant",
      "model": "Claude Opus",
      "colour": "blue",
      "icon": "Brain",
      "active": true
    }
  ]
}
```

| Field | Description |
|-------|-------------|
| `id` | Agent identifier (use this for group chat creation, triggers, etc.) |
| `name` | Agent display name |
| `model` | AI model the agent uses |
| `colour` | Agent colour theme |
| `icon` | Agent icon name |
| `active` | Whether the agent is active |

---

### Get Agent

```
GET /api/v1/agents/:id
```

Returns a single agent by ID.

---

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
      "group_chat": false,
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
| `group_chat` | true if this is a group chat with agents |
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
    "group_chat": true,
    "agents": [
      { "id": "ag1", "name": "Research Assistant" },
      { "id": "ag2", "name": "Code Reviewer" }
    ],
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
        "author": "Research Assistant",
        "timestamp": "2026-01-15T09:00:15Z"
      }
    ]
  }
}
```

Note: Transcript excludes images, thinking traces, and tool calls for cleaner output.

---

### Create Conversation

```
POST /api/v1/conversations
Content-Type: application/json

{
  "title": "Project Discussion",
  "message": "Let's discuss the roadmap",
  "model_id": "openrouter/auto",
  "agent_ids": ["ag1", "ag2"]
}
```

Creates a new conversation. Include `agent_ids` to create a group chat with agents.

| Field | Required | Description |
|-------|----------|-------------|
| `title` | No | Conversation title |
| `message` | No | Initial message content |
| `model_id` | No | AI model to use (defaults to "openrouter/auto") |
| `agent_ids` | No | Array of agent IDs to create a group chat |

**Response (201):**
```json
{
  "conversation": {
    "id": "abc123",
    "title": "Project Discussion",
    "group_chat": true,
    "agents": [
      { "id": "ag1", "name": "Research Assistant" },
      { "id": "ag2", "name": "Code Reviewer" }
    ],
    "created_at": "2026-01-15T09:00:00Z"
  }
}
```

**Notes:**
- Without `agent_ids`, creates a regular 1-1 chat. AI responds automatically to messages.
- With `agent_ids`, creates a group chat. Agents must be triggered manually (see Agent Trigger below).
- All agent IDs must belong to active agents on your account.

---

### List Messages in Conversation

```
GET /api/v1/conversations/:id/messages
```

Returns the message transcript for a conversation. This is a convenience endpoint that returns the same transcript data as the conversation show endpoint.

**Response:**
```json
{
  "messages": [
    {
      "role": "user",
      "content": "Let's plan the Q1 roadmap",
      "author": "Daniel",
      "timestamp": "2026-01-15T09:00:00Z"
    },
    {
      "role": "assistant",
      "content": "I'd be happy to help...",
      "author": "Research Assistant",
      "timestamp": "2026-01-15T09:00:15Z"
    }
  ]
}
```

Note: Like the conversation show endpoint, this excludes images, thinking traces, and tool calls.

---

### Post Message to Conversation

```
POST /api/v1/conversations/:id/messages
Content-Type: application/json

{
  "content": "Your message here"
}
```

Posts a message as the authenticated user.

**Response (201):**
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
| `ai_response_triggered` | true if AI will respond automatically (1-1 chats only). Group chats require manual triggers. |

**Errors:**
- `422` - Conversation is archived or deleted

---

### Trigger Agent Response

```
POST /api/v1/conversations/:conversation_id/agent_trigger
Content-Type: application/json

{
  "agent_id": "ag1"
}
```

Triggers an agent to respond in a group chat. Omit `agent_id` to trigger all agents.

| Field | Required | Description |
|-------|----------|-------------|
| `agent_id` | No | Specific agent to trigger. Omit to trigger all agents. |

**Response:**
```json
{
  "triggered": [
    { "id": "ag1", "name": "Research Assistant" }
  ]
}
```

**Errors:**
- `422` - Not a group chat, or conversation is archived/deleted
- `404` - Agent not found in this conversation

---

### Add Participant to Group Chat

```
POST /api/v1/conversations/:conversation_id/participants
Content-Type: application/json

{
  "agent_id": "ag2"
}
```

Adds an agent to an existing group chat. A system notice is posted to the conversation.

| Field | Required | Description |
|-------|----------|-------------|
| `agent_id` | Yes | Agent to add to the conversation |

**Response (201):**
```json
{
  "participant": { "id": "ag2", "name": "Code Reviewer" },
  "agents": [
    { "id": "ag1", "name": "Research Assistant" },
    { "id": "ag2", "name": "Code Reviewer" }
  ]
}
```

**Errors:**
- `422` - Not a group chat, agent already in conversation, or conversation archived/deleted
- `404` - Agent not found or inactive

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
  "content": "# Initial content",
  "summary": "Optional short summary"
}
```

| Field | Required | Description |
|-------|----------|-------------|
| `name` | Yes | Whiteboard name (max 100 chars, must be unique) |
| `content` | No | Initial content (max 100,000 chars) |
| `summary` | No | Short summary (max 250 chars) |

**Response (201):**
```json
{
  "whiteboard": {
    "id": "wb456",
    "name": "My New Whiteboard",
    "lock_version": 0
  }
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
    "content": "# Meeting Notes...",
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
  "content": "# Updated content",
  "lock_version": 3
}
```

Uses optimistic locking to prevent conflicts.

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

---

## Rate Limits

No rate limits currently enforced.

---

## Example: Group Chat Workflow

```bash
# 1. List available agents
curl -H "Authorization: Bearer $HELIX_API_KEY" \
  https://your-domain/api/v1/agents

# 2. Create a group chat with two agents
curl -X POST \
  -H "Authorization: Bearer $HELIX_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"title":"Architecture Review", "message":"Review the API", "agent_ids":["ag1","ag2"]}' \
  https://your-domain/api/v1/conversations

# 3. Post a message
curl -X POST \
  -H "Authorization: Bearer $HELIX_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"content":"What do you think?"}' \
  https://your-domain/api/v1/conversations/abc123/messages

# 4. Trigger a specific agent to respond
curl -X POST \
  -H "Authorization: Bearer $HELIX_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"agent_id":"ag1"}' \
  https://your-domain/api/v1/conversations/abc123/agent_trigger

# 5. Or trigger all agents
curl -X POST \
  -H "Authorization: Bearer $HELIX_API_KEY" \
  https://your-domain/api/v1/conversations/abc123/agent_trigger

# 6. Add another agent mid-conversation
curl -X POST \
  -H "Authorization: Bearer $HELIX_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"agent_id":"ag3"}' \
  https://your-domain/api/v1/conversations/abc123/participants
```

## Example: Simple 1-1 Chat

```bash
# Create a chat (AI responds automatically)
curl -X POST \
  -H "Authorization: Bearer $HELIX_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"title":"Quick Question", "message":"What is HelixKit?"}' \
  https://your-domain/api/v1/conversations

# Read the conversation
curl -H "Authorization: Bearer $HELIX_API_KEY" \
  https://your-domain/api/v1/conversations/abc123
```
