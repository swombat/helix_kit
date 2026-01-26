# Streaming Race Condition Fix - Implementation Specification (v2)

## Executive Summary

This specification addresses a race condition where ActionCable streaming updates are lost because the frontend subscription is not established before the backend begins broadcasting. The solution uses ActionCable's built-in `transmit` method to deliver current state when a streaming message subscription connects.

**Total changes: One method in SyncChannel (~10 lines), one case in handleStreamingUpdate (~5 lines), one event listener in show.svelte (~15 lines).**

## The Problem

### Race Condition Timeline

```
Time ->
Backend:    [Message Created] -> [Job Starts] -> [Broadcast Chunk 1] -> [Chunk 2] -> [Chunk 3] -> ...
                    |
Frontend:   [Inertia Props] -> [Component Mounts] -> [Subscribes to ActionCable] -> [Receives Chunk 4+]
                                                                                           ^
                                                                              CHUNKS 1-3 LOST
```

The frontend receives the message via Inertia props, mounts the component, and subscribes to ActionCable. But by then, chunks have already been broadcast and lost. The current mitigation triggers an Inertia reload when streaming ends, causing visual jank.

## Solution Architecture

### Core Principle: Server Delivers State on Connect

When a subscription connects, the server should deliver the current database state. ActionCable supports this natively via `transmit` in the `subscribed` callback. No new endpoints. No client-side fetching.

```
Time ->
Backend:    [Message Created] -> [Job Starts] -> [Broadcast Chunks] -> ... -> [End]
                    |
Frontend:   [Inertia Props] -> [Mount] -> [Subscribe] -> [Receive current_state] -> [Apply Chunks]
                                                                |
                                                         Server sends DB state
                                                         on subscription connect
```

### Data Flow

1. Backend creates message, starts streaming immediately (no changes)
2. Frontend receives Inertia props with message (initial content may be empty or partial)
3. Frontend subscribes to `Message:{id}` channel
4. **New**: SyncChannel detects streaming message and `transmit`s current state
5. Frontend receives `current_state` action, updates `recentMessages` directly
6. Subsequent `streaming_update` events append chunks as before
7. On `streaming_end`, content is already complete (no jank)

## Implementation Plan

### Step 1: Update SyncChannel to Transmit Current State

Add a method to transmit current state for streaming messages when subscription connects.

```ruby
# app/channels/sync_channel.rb

def subscribed
  # ... existing authorization code ...

  if params[:id].include?(":")
    setup_collection_subscription
  else
    stream_from "#{params[:model]}:#{params[:id]}"
    deliver_current_state_if_streaming
  end
end

private

def deliver_current_state_if_streaming
  return unless params[:model] == 'Message'
  return unless @model&.streaming?

  transmit(
    action: 'current_state',
    id: @model.obfuscated_id,
    content: @model.content,
    thinking: @model.thinking_text
  )
end
```

- [ ] Add `deliver_current_state_if_streaming` method to `SyncChannel`
- [ ] Call it after `stream_from` in `subscribed` (non-collection case)

### Step 2: Update cable.js to Dispatch streaming-state Event

Handle the new `current_state` action in the existing `handleStreamingUpdate` function.

```javascript
// app/frontend/lib/cable.js

function handleStreamingUpdate(data) {
  if (data.action === 'current_state') {
    if (browser) {
      window.dispatchEvent(new CustomEvent('streaming-state', { detail: data }));
    }
    return true;
  } else if (data.action === 'streaming_update') {
    // ... existing code ...
  } else if (data.action === 'streaming_end') {
    // ... existing code ...
  } else if (data.action === 'debug_log') {
    // ... existing code ...
  }
}
```

- [ ] Add `current_state` case to `handleStreamingUpdate` in `cable.js`
- [ ] Dispatch `streaming-state` custom event

### Step 3: Update show.svelte to Handle streaming-state Event

Add a listener in the existing `streamingSync` setup to handle the new event.

```javascript
// In show.svelte, update the streamingSync call or add alongside it

onMount(() => {
  if (typeof window === 'undefined') return;

  const handleStreamingState = (event) => {
    const data = event.detail;
    logging.debug('Received streaming state:', data);

    if (data.id) {
      const index = recentMessages.findIndex((m) => m.id === data.id);
      if (index !== -1 && recentMessages[index].streaming) {
        recentMessages = recentMessages.map((message, i) =>
          i === index
            ? { ...message, content: data.content, thinking: data.thinking }
            : message
        );
      }
    }
  };

  window.addEventListener('streaming-state', handleStreamingState);

  return () => {
    window.removeEventListener('streaming-state', handleStreamingState);
  };
});
```

- [ ] Add `streaming-state` event listener in `show.svelte`
- [ ] Update `recentMessages` directly when state is received

## Testing Strategy

### Unit Tests

- [ ] Test that `SyncChannel#deliver_current_state_if_streaming` transmits for streaming messages
- [ ] Test that `SyncChannel#deliver_current_state_if_streaming` does not transmit for non-streaming messages
- [ ] Test that the transmit includes correct content and thinking fields

### Integration Tests

- [ ] Test that frontend receives `current_state` event when subscribing to streaming message
- [ ] Test that message content updates correctly from `current_state`

### Manual Testing

- [ ] Start a new chat, verify no visual jank during AI response
- [ ] Test on slow network (throttle in DevTools)
- [ ] Verify content appears immediately after subscription connects

## Edge Cases

### 1. Message Already Finished Streaming

If a message has `streaming: false` by the time subscription connects, `deliver_current_state_if_streaming` returns early. No harm done - the content from Inertia props is already complete.

### 2. Chunks Arrive Before current_state

The `current_state` event replaces content entirely. If a few chunks snuck in before `current_state` arrives, they get overwritten with the authoritative database state. This is correct behavior.

### 3. current_state Arrives After Streaming Ends

The guard `recentMessages[index].streaming` ensures we only update messages that are still streaming. If streaming already ended (via Inertia reload), the update is ignored.

## Why This Approach

### What DHH Said

> "When you find yourself adding API endpoints to compensate for race conditions in your real-time layer, you are solving the wrong problem."

> "The subscription connection itself should include current state. ActionCable supports this natively via `transmit` in the `subscribed` callback."

> "No new endpoints. No callback soup. No dual state. The Rails Way."

### Comparison to v1

| Aspect | v1 (Rejected) | v2 (This Spec) |
|--------|---------------|----------------|
| New endpoints | 1 (snapshot) | 0 |
| New functions | 3 (subscribeToStreamingMessage, fetchSnapshot, useStreamingMessage) | 0 |
| New state objects | 1 (streamingMessages) | 0 |
| Callbacks | 3 (onSnapshot, onChunk, onEnd) | 0 |
| Sources of truth | 2 (recentMessages + streamingMessages) | 1 (recentMessages) |
| Lines of code | ~150 | ~30 |

## Files Changed

| File | Change |
|------|--------|
| `app/channels/sync_channel.rb` | Add `deliver_current_state_if_streaming` method |
| `app/frontend/lib/cable.js` | Add `current_state` case to `handleStreamingUpdate` |
| `app/frontend/pages/chats/show.svelte` | Add `streaming-state` event listener |

## Implementation Checklist

### Backend
- [ ] Add `deliver_current_state_if_streaming` private method to `SyncChannel`
- [ ] Call the method after `stream_from` in `subscribed`
- [ ] Add channel test for `current_state` transmission

### Frontend
- [ ] Add `current_state` handling to `handleStreamingUpdate` in `cable.js`
- [ ] Add `streaming-state` event listener in `show.svelte`
- [ ] Test manually on various network conditions

### Testing
- [ ] Unit test SyncChannel transmit behavior
- [ ] Integration test full streaming flow
- [ ] Manual testing checklist complete
