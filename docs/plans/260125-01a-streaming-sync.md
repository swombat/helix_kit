# Streaming Race Condition Fix - Implementation Specification

## Executive Summary

This specification addresses a race condition where ActionCable streaming updates are lost because the frontend subscription is not established before the backend begins broadcasting. The solution uses a **snapshot-on-subscribe** pattern: when the frontend subscribes to a streaming message, it immediately fetches the current content from the database, then applies subsequent streaming updates. This eliminates the race without adding latency or complexity.

## The Problem

### Race Condition Timeline

```
Time →
Backend:    [Message Created] → [Job Starts] → [Broadcast Chunk 1] → [Chunk 2] → [Chunk 3] → ...
                    ↓
Frontend:   [Inertia Props] → [Component Mounts] → [Subscribes to ActionCable] → [Receives Chunk 4+]
                                                                                       ↑
                                                                              CHUNKS 1-3 LOST
```

The frontend receives the message via Inertia props, mounts the component, and subscribes to ActionCable. But by then, chunks have already been broadcast and lost.

### Current Mitigation

The codebase already has a fallback: when streaming ends, the frontend triggers an Inertia reload to fetch the complete message. This ensures eventual consistency but causes visual jank.

## Solution Architecture

### Core Principle: Snapshot on Subscribe

Instead of trying to synchronize the start of streaming with subscription, we accept that chunks may be missed and compensate by fetching the current state when subscribing.

```
Time →
Backend:    [Message Created] → [Job Starts] → [Broadcast Chunks] → ... → [End]
                    ↓
Frontend:   [Inertia Props] → [Mount] → [Subscribe + Fetch Snapshot] → [Apply Chunks]
                                                     ↓
                                              Start from DB state,
                                              not from empty
```

### Data Flow

1. Backend creates message, starts streaming immediately (no changes)
2. Frontend receives Inertia props with message (initial content may be empty or partial)
3. Frontend subscribes to `Message:{id}` channel
4. **New**: On subscription, frontend fetches current message content via lightweight API
5. Frontend updates local state with snapshot
6. Subsequent `streaming_update` events append to the snapshot
7. On `streaming_end`, no jarring reload needed (content is already complete)

## Implementation Plan

### Step 1: Add Snapshot API Endpoint

A lightweight endpoint that returns only the streaming-relevant fields.

```ruby
# app/controllers/messages_controller.rb

def snapshot
  @message = Message.find(params[:id])

  # Authorization via association
  @chat = if Current.user.site_admin
    Chat.find(@message.chat_id)
  else
    Chat.where(id: @message.chat_id, account_id: Current.user.account_ids).first!
  end

  render json: {
    content: @message.content,
    streaming: @message.streaming,
    thinking: @message.thinking_text
  }
end
```

- [ ] Add `snapshot` action to `MessagesController`
- [ ] Add route: `get '/messages/:id/snapshot', to: 'messages#snapshot'`
- [ ] Test authorization works correctly

### Step 2: Update Frontend Cable Integration

Modify the streaming sync to fetch a snapshot when subscribing to a streaming message.

```javascript
// app/frontend/lib/cable.js

export function subscribeToStreamingMessage(messageId, onSnapshot, onChunk, onEnd) {
  if (!browser || !consumer) return () => {};

  let contentBuffer = '';
  let hasSnapshot = false;

  const subscription = consumer.subscriptions.create(
    {
      channel: 'SyncChannel',
      model: 'Message',
      id: messageId,
    },
    {
      connected() {
        logging.debug(`Streaming connected: Message:${messageId}`);
        // Fetch current state immediately on connect
        fetchSnapshot(messageId).then(snapshot => {
          if (snapshot) {
            hasSnapshot = true;
            contentBuffer = snapshot.content || '';
            onSnapshot(snapshot);
          }
        });
      },

      received(data) {
        if (data.action === 'streaming_update' && data.chunk) {
          // If we have a snapshot, append chunk
          // If not, buffer chunks until we get one
          if (hasSnapshot) {
            contentBuffer += data.chunk;
            onChunk(contentBuffer, data.chunk);
          } else {
            // Race: chunk arrived before snapshot fetch completed
            // Store for later application
            contentBuffer += data.chunk;
          }
        } else if (data.action === 'streaming_end') {
          onEnd(contentBuffer);
        } else if (data.action === 'thinking_update' && data.chunk) {
          // Pass thinking updates through
          window.dispatchEvent(new CustomEvent('streaming-update', {
            detail: { ...data, id: messageId }
          }));
        }
      },

      disconnected() {
        logging.debug(`Streaming disconnected: Message:${messageId}`);
      },
    }
  );

  return () => subscription.unsubscribe();
}

async function fetchSnapshot(messageId) {
  try {
    const response = await fetch(`/messages/${messageId}/snapshot`, {
      headers: {
        'Accept': 'application/json',
        'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]')?.content || '',
      },
    });
    if (response.ok) {
      return await response.json();
    }
  } catch (error) {
    logging.error('Failed to fetch message snapshot:', error);
  }
  return null;
}
```

- [ ] Add `subscribeToStreamingMessage` function to `cable.js`
- [ ] Add `fetchSnapshot` helper function
- [ ] Export new function

### Step 3: Update use-sync.js

Add a specialized streaming sync hook that uses the new subscription method.

```javascript
// app/frontend/lib/use-sync.js

import { subscribeToStreamingMessage } from './cable';

/**
 * Hook for synchronizing a streaming message
 * Handles the snapshot-on-subscribe pattern
 */
export function useStreamingMessage(messageId, callbacks) {
  let unsubscribe = null;

  onMount(() => {
    if (!messageId) return;

    logging.debug('Setting up streaming subscription for:', messageId);

    unsubscribe = subscribeToStreamingMessage(
      messageId,
      callbacks.onSnapshot,
      callbacks.onChunk,
      callbacks.onEnd
    );
  });

  onDestroy(() => {
    if (unsubscribe) {
      unsubscribe();
    }
  });
}
```

- [ ] Add `useStreamingMessage` hook to `use-sync.js`
- [ ] Export the hook

### Step 4: Update Chat Component

Modify the chat component to use the new streaming approach.

```svelte
<!-- Key changes to app/frontend/pages/chats/show.svelte -->

<script>
  import { useStreamingMessage } from '$lib/use-sync';

  // Track which messages are being streamed with snapshot-based content
  let streamingMessages = $state({});

  // Find the currently streaming message
  const streamingMessageId = $derived(
    recentMessages.find(m => m.streaming && m.role === 'assistant')?.id
  );

  // Set up streaming subscription when we have a streaming message
  $effect(() => {
    if (!streamingMessageId) return;

    // Clean up any stale state
    delete streamingMessages[streamingMessageId];

    const unsub = subscribeToStreamingMessage(
      streamingMessageId,
      // onSnapshot
      (snapshot) => {
        streamingMessages[streamingMessageId] = {
          content: snapshot.content || '',
          thinking: snapshot.thinking || '',
        };
        streamingMessages = { ...streamingMessages };
      },
      // onChunk
      (fullContent, chunk) => {
        if (streamingMessages[streamingMessageId]) {
          streamingMessages[streamingMessageId].content = fullContent;
          streamingMessages = { ...streamingMessages };
        }
        scrollToBottomIfNeeded();
      },
      // onEnd
      (finalContent) => {
        // Update the message in recentMessages
        recentMessages = recentMessages.map(m =>
          m.id === streamingMessageId
            ? { ...m, content: finalContent, streaming: false }
            : m
        );
        delete streamingMessages[streamingMessageId];
        streamingMessages = { ...streamingMessages };
      }
    );

    return unsub;
  });

  // Get display content for a message
  function getDisplayContent(message) {
    if (streamingMessages[message.id]) {
      return streamingMessages[message.id].content;
    }
    return message.content || '';
  }
</script>

<!-- In the message rendering, use getDisplayContent() -->
<Streamdown
  content={getDisplayContent(message)}
  parseIncompleteMarkdown
  baseTheme="shadcn"
  class="prose"
  animation={{
    enabled: true,
    type: 'fade',
    tokenize: 'word',
    duration: 300,
    timingFunction: 'ease-out',
    animateOnMount: true,
  }} />
```

- [ ] Add `streamingMessages` state to track snapshot-based content
- [ ] Add `streamingMessageId` derived value
- [ ] Add effect to set up streaming subscription
- [ ] Add `getDisplayContent` helper function
- [ ] Update message rendering to use `getDisplayContent`
- [ ] Remove dependency on global `streaming-update` events for content (keep for thinking)

### Step 5: Simplify streamingSync

The global `streamingSync` can be simplified since content updates now go through the snapshot pattern.

```javascript
// Updated streamingSync in use-sync.js
// Now only handles thinking updates and streaming-end (as fallback)

export function streamingSync(streamUpdate, streamEnd) {
  onMount(() => {
    logging.debug('Setting up streaming event listeners (thinking only)');
    if (typeof window === 'undefined') return;

    const handleStreamingUpdate = (event) => {
      const data = event.detail;
      // Only handle thinking updates - content is handled by useStreamingMessage
      if (data.action === 'thinking_update') {
        streamUpdate(data);
      }
    };

    const handleStreamingEnd = (event) => {
      const data = event.detail;
      logging.debug('Received streaming end:', data);
      streamEnd(data);
    };

    window.addEventListener('streaming-update', handleStreamingUpdate);
    window.addEventListener('streaming-end', handleStreamingEnd);

    return () => {
      window.removeEventListener('streaming-update', handleStreamingUpdate);
      window.removeEventListener('streaming-end', handleStreamingEnd);
    };
  });
}
```

- [ ] Update `streamingSync` to only handle thinking updates
- [ ] Keep `streaming-end` handling as fallback

### Step 6: Add Route

```ruby
# config/routes.rb
resources :messages, only: [:update, :destroy] do
  member do
    post :retry
    post :fix_hallucinated_tool_calls
    get :snapshot  # Add this
  end
end
```

- [ ] Add `snapshot` route to messages resource

## Testing Strategy

### Unit Tests

- [ ] Test `MessagesController#snapshot` returns correct JSON
- [ ] Test snapshot endpoint authorization (only accessible to chat participants)
- [ ] Test snapshot returns streaming state correctly

### Integration Tests

- [ ] Test complete streaming flow with snapshot pattern
- [ ] Test race condition scenario: subscription after chunks started
- [ ] Test chunk buffering when snapshot fetch is slow
- [ ] Test thinking updates still work alongside content streaming

### Manual Testing Checklist

- [ ] Start a new chat, verify no visual jank during AI response
- [ ] Send message while another tab is open, verify sync works
- [ ] Test on slow network (throttle in DevTools)
- [ ] Verify final message content matches across all scenarios

## Edge Cases

### 1. Snapshot Fetch Fails

If the snapshot fetch fails, fall back to the existing behavior: the message will appear empty/partial until streaming ends, then get the final content via the streaming_end reload.

### 2. Chunks Arrive Before Snapshot

The `contentBuffer` in the subscription accumulates all chunks. When the snapshot arrives, it provides the starting state, and any chunks received after that are additive.

### 3. Message Already Finished Streaming

If a message has `streaming: false` in the snapshot, the subscription still works correctly - there will simply be no streaming_update events, and the snapshot content is already complete.

### 4. Multiple Messages Streaming

Each streaming message gets its own subscription and snapshot. The `streamingMessages` state object tracks them independently by ID.

### 5. Navigation During Streaming

The Svelte effect cleanup and subscription unsubscribe ensure proper cleanup when navigating away.

## Performance Considerations

1. **Minimal API overhead**: The snapshot endpoint returns only 3 fields, using `render json:` (fast)
2. **Single snapshot per message**: Only fetched once on subscription, not repeatedly
3. **No additional database queries during streaming**: The existing `stream_content` method already writes to DB
4. **Debounced streaming unchanged**: The 200ms content debounce in `StreamsAiResponse` still applies

## Security

- Snapshot endpoint uses existing authorization pattern (association-based)
- No new attack surface - just exposing data already available via Inertia props
- CSRF token required for fetch

## Migration Path

This is a purely additive change:

1. Deploy backend changes (new endpoint + route)
2. Deploy frontend changes (new subscription pattern)
3. Old behavior continues to work during deployment window
4. New behavior activates automatically for new streaming sessions

## Why This Approach

### Alternatives Considered

1. **Delay backend streaming until frontend ready**: Would add latency, complex signaling
2. **Server-side buffering with replay**: More complex, memory concerns, doesn't fit Rails Way
3. **Include all content in Inertia props**: Already done, but props arrive before subscription
4. **Frontend polling during streaming**: Inefficient, adds latency

### Why Snapshot-on-Subscribe Wins

- **Simple**: One fetch on subscribe, then additive updates
- **No latency added**: Backend streams immediately, no waiting
- **Eventually consistent**: Even if chunks are missed, snapshot provides recovery
- **Rails Way**: Thin endpoint, model contains logic, associations handle auth
- **Fail-safe**: Falls back gracefully to existing behavior if snapshot fails

## Files Changed

| File | Change |
|------|--------|
| `app/controllers/messages_controller.rb` | Add `snapshot` action |
| `config/routes.rb` | Add `snapshot` route |
| `app/frontend/lib/cable.js` | Add `subscribeToStreamingMessage`, `fetchSnapshot` |
| `app/frontend/lib/use-sync.js` | Add `useStreamingMessage`, simplify `streamingSync` |
| `app/frontend/pages/chats/show.svelte` | Use snapshot-based streaming |

## Implementation Checklist

### Backend
- [ ] Add `MessagesController#snapshot` action
- [ ] Add route for snapshot endpoint
- [ ] Add controller test for snapshot

### Frontend
- [ ] Add `subscribeToStreamingMessage` to cable.js
- [ ] Add `fetchSnapshot` helper to cable.js
- [ ] Add `useStreamingMessage` hook to use-sync.js
- [ ] Update show.svelte to use snapshot pattern
- [ ] Simplify existing streamingSync (thinking only)
- [ ] Test on various network conditions

### Testing
- [ ] Unit test snapshot endpoint
- [ ] Integration test full streaming flow
- [ ] Manual testing checklist complete
