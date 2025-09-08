# Chat with RubyLLM - API Usage Guide

This document explains how to use the chat API powered by RubyLLM from a frontend application.

## Overview

The chat system supports AI conversations using three providers:
- OpenAI (GPT models)
- Anthropic (Claude models)  
- OpenRouter (automatic model routing)

The default model is `openrouter/auto` which intelligently routes requests to the best available model.

## API Endpoints

### Chats

#### List all chats for an account
```
GET /accounts/:account_id/chats
```

Returns all chats for the account, ordered by most recent first.

**Response:**
```javascript
{
  chats: [
    {
      id: "obfuscated_id",
      title: "Chat about Rails",
      model_id: "openrouter/auto",
      created_at: "2025-01-06T10:00:00Z",
      updated_at: "2025-01-06T10:30:00Z"
    }
  ]
}
```

#### Get a specific chat with messages
```
GET /accounts/:account_id/chats/:id
```

Returns the chat and all its messages.

**Response:**
```javascript
{
  chat: {
    id: "obfuscated_id",
    title: "Chat about Rails",
    model_id: "openrouter/auto",
    created_at: "2025-01-06T10:00:00Z",
    updated_at: "2025-01-06T10:30:00Z"
  },
  messages: [
    {
      id: "msg_id",
      role: "user",
      content: "How do I use Rails associations?",
      user_id: "user_id",
      created_at: "2025-01-06T10:00:00Z"
    },
    {
      id: "msg_id_2",
      role: "assistant",
      content: "Rails associations allow you to...",
      user_id: null,
      created_at: "2025-01-06T10:00:05Z"
    }
  ]
}
```

#### Create a new chat
```
POST /accounts/:account_id/chats
```

Creates an empty chat container. This two-step approach (create chat, then add messages) simplifies the UI flow by:
- Allowing immediate display of an empty chat interface
- Establishing the model selection before any messages
- Creating a chat ID for real-time subscriptions
- Making the message form work consistently for first and subsequent messages

**Request body (optional):**
```javascript
{
  chat: {
    model_id: "gpt-4"  // Optional, defaults to "openrouter/auto"
  }
}
```

**Response:**
Redirects to the chat page (302)

#### Delete a chat
```
DELETE /accounts/:account_id/chats/:id
```

Deletes the chat and all its messages.

**Response:**
Redirects to the chats index page (302)

### Messages

#### Create a message (and trigger AI response)
```
POST /accounts/:account_id/chats/:chat_id/messages
```

Creates a user message and automatically triggers an AI response via background job.

**Request body:**
```javascript
{
  message: {
    content: "Your question or message here"
  },
  files: []  // Optional array of file attachments for vision models
}
```

**Response:**
Redirects to the chat page (302)

The AI response will be streamed in real-time via ActionCable broadcasts.

## Real-time Updates

The chat system uses ActionCable for real-time updates. Messages broadcast changes as they're created and updated.

### Subscribing to updates

In your Svelte component:

```javascript
import { onMount, onDestroy } from 'svelte';
import { subscribe } from '$lib/sync';

let chat = $props();
let messages = $props();

onMount(() => {
  // Subscribe to chat updates (for title changes)
  const chatUnsub = subscribe(`chat:${chat.id}`, () => {
    // Inertia will automatically reload the chat prop
  });
  
  // Subscribe to message updates (for new messages and streaming content)
  const messagesUnsub = subscribe(`chat:${chat.id}:messages`, () => {
    // Inertia will automatically reload the messages prop
  });
  
  onDestroy(() => {
    chatUnsub();
    messagesUnsub();
  });
});
```

## Typical Frontend Flow

### 1. Creating a new conversation

```javascript
// Create an empty chat
const response = await fetch(`/accounts/${accountId}/chats`, {
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
    'X-CSRF-Token': getCsrfToken()
  },
  body: JSON.stringify({
    chat: {
      model_id: selectedModel || 'openrouter/auto'
    }
  })
});

// Response will redirect to the new chat page
const chatUrl = response.headers.get('Location');
window.location.href = chatUrl;
```

### 2. Sending a message

```javascript
// Send a message (from the chat page)
const response = await fetch(`/accounts/${accountId}/chats/${chatId}/messages`, {
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
    'X-CSRF-Token': getCsrfToken()
  },
  body: JSON.stringify({
    message: {
      content: userInput
    }
  })
});

// The AI response will stream in via ActionCable
// No need to poll or refresh - updates are automatic
```

### 3. Handling streaming responses

The AI responses stream token by token. The Message model's content is updated incrementally, and each update triggers a broadcast:

```javascript
// In your Svelte component
let messages = $props();

// Find the assistant message that's being streamed
$effect(() => {
  const streamingMessage = messages.find(m => 
    m.role === 'assistant' && 
    m.created_at > recentTimestamp
  );
  
  if (streamingMessage) {
    // Update UI with partial content
    displayMessage(streamingMessage.content);
  }
});
```

## File Attachments

For vision models, you can attach images:

```javascript
const formData = new FormData();
formData.append('message[content]', 'What is in this image?');
formData.append('files[]', imageFile);

const response = await fetch(`/accounts/${accountId}/chats/${chatId}/messages`, {
  method: 'POST',
  headers: {
    'X-CSRF-Token': getCsrfToken()
  },
  body: formData
});
```

## Model Selection

Available models depend on your configured providers:

- **OpenRouter**: `openrouter/auto` (default), or specific models like `openrouter/gpt-4`
- **OpenAI**: `gpt-4`, `gpt-3.5-turbo`, etc.
- **Anthropic**: `claude-3-opus`, `claude-3-sonnet`, etc.

The model is set when creating the chat and cannot be changed afterward (to maintain conversation consistency).

## Error Handling

The API returns standard HTTP status codes:

- `200 OK` - Success
- `302 Found` - Redirect after successful creation
- `404 Not Found` - Chat or account not found
- `422 Unprocessable Entity` - Validation errors
- `500 Internal Server Error` - Server error or AI provider issue

AI provider errors (rate limits, API failures) are handled gracefully in the background jobs and won't crash the application.

## Best Practices

1. **Always subscribe to real-time updates** for active chats to show streaming responses
2. **Handle empty states** - chats may have no messages initially
3. **Show loading indicators** while waiting for AI responses
4. **Implement retry logic** for failed message sends
5. **Validate message content** on the frontend before sending
6. **Use Inertia's built-in navigation** instead of full page refreshes
7. **Store the selected model** in user preferences for future chats

## Implementation Notes

### Why separate chat creation from first message?

The API separates chat creation from message sending to simplify the UI implementation:

1. **Consistent UI flow**: The message form works the same whether it's the first or hundredth message
2. **Immediate feedback**: Users see the chat interface right away with the selected model
3. **Real-time ready**: The chat ID exists for subscriptions before any messages
4. **Cleaner navigation**: Each action has a clear endpoint and redirect

While this means chats can exist without messages, the trade-off provides a simpler, more predictable frontend implementation.

### Background Processing

AI responses are processed in background jobs (`AiResponseJob`) to keep the UI responsive. The job:
1. Creates an empty assistant message immediately
2. Streams the AI response token by token
3. Updates the message content incrementally
4. Broadcasts each update via ActionCable

This approach ensures users see responses appearing in real-time rather than waiting for the complete response.

### Title Generation

Chat titles are automatically generated from the first user message via `GenerateTitleJob`. This happens asynchronously and doesn't block the conversation flow.