# Streaming Race Condition Fix - Final Implementation Specification (v3)

## Executive Summary

This specification addresses a race condition where ActionCable streaming updates are lost because the frontend subscription is not established before the backend begins broadcasting. The solution uses ActionCable's built-in `transmit` method to deliver current state when a streaming message subscription connects.

**Total changes: ~30 lines across 3 files. No new endpoints. No new abstractions.**

## The Problem

```
Time ->
Backend:    [Message Created] -> [Job Starts] -> [Broadcast Chunk 1] -> [Chunk 2] -> [Chunk 3] -> ...
                    |
Frontend:   [Inertia Props] -> [Component Mounts] -> [Subscribes to ActionCable] -> [Receives Chunk 4+]
                                                                                           ^
                                                                              CHUNKS 1-3 LOST
```

The frontend receives the message via Inertia props, mounts the component, and subscribes to ActionCable. But by then, chunks have already been broadcast and lost.

## Solution

When a subscription connects, the server delivers the current database state via `transmit`. No new endpoints. No client-side fetching.

```
Time ->
Backend:    [Message Created] -> [Job Starts] -> [Broadcast Chunks] -> ... -> [End]
                    |
Frontend:   [Inertia Props] -> [Mount] -> [Subscribe] -> [Receive current_state] -> [Apply Chunks]
                                                                |
                                                         Server sends DB state
                                                         on subscription connect
```

## Implementation

### Step 1: SyncChannel - Deliver State on Subscribe

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
  return unless params[:model] == "Message"
  return unless @model&.streaming?

  transmit(
    action: "current_state",
    id: @model.obfuscated_id,
    content: @model.content,
    thinking: @model.thinking
  )
end
```

- [x] Add `deliver_current_state_if_streaming` private method to `SyncChannel`
- [x] Call the method after `stream_from` in `subscribed` (non-collection branch)

### Step 2: cable.js - Event Map Pattern

Refactor `handleStreamingUpdate` to use an event map instead of if/else chain.

```javascript
// app/frontend/lib/cable.js

function handleStreamingUpdate(data) {
  const eventMap = {
    current_state: 'streaming-state',
    streaming_update: 'streaming-update',
    streaming_end: 'streaming-end',
    debug_log: 'debug-log'
  };

  const eventName = eventMap[data.action];
  if (eventName && browser) {
    window.dispatchEvent(new CustomEvent(eventName, { detail: data }));
    return true;
  }
}
```

- [ ] Replace if/else chain with event map pattern in `handleStreamingUpdate`

### Step 3: use-sync.js - Extend streamingSync with Third Callback

Extend `streamingSync` to accept an optional third callback for `current_state` events. Use array-based listener management for cleaner cleanup.

```javascript
// app/frontend/lib/use-sync.js

export function streamingSync(streamUpdate, streamEnd, streamState = null) {
  onMount(() => {
    logging.debug('Setting up streaming event listeners');
    if (typeof window === 'undefined') return;

    const listeners = [
      ['streaming-update', (e) => streamUpdate(e.detail)],
      ['streaming-end', (e) => streamEnd(e.detail)],
    ];

    if (streamState) {
      listeners.push(['streaming-state', (e) => streamState(e.detail)]);
    }

    listeners.forEach(([event, handler]) => {
      window.addEventListener(event, handler);
    });

    return () => {
      listeners.forEach(([event, handler]) => {
        window.removeEventListener(event, handler);
      });
    };
  });
}
```

- [ ] Update `streamingSync` to accept optional third `streamState` callback
- [ ] Use array-based listener management for cleaner add/remove

### Step 4: show.svelte - Add Third Callback

Add the `current_state` handler as a third callback to the existing `streamingSync` call.

```javascript
// app/frontend/pages/chats/show.svelte (update existing streamingSync call at line 491)

streamingSync(
  (data) => {
    // existing streaming_update logic (lines 493-529)
    if (data.id) {
      const index = recentMessages.findIndex((m) => m.id === data.id);
      if (index !== -1) {
        if (data.action === 'thinking_update') {
          streamingThinking[data.id] = (streamingThinking[data.id] || '') + (data.chunk || '');
        } else if (data.action === 'streaming_update') {
          logging.debug('Updating message via streaming:', data.id, data.chunk);
          const currentMessage = recentMessages[index] || {};
          const updatedMessage = {
            ...currentMessage,
            content: `${currentMessage.content || ''}${data.chunk || ''}`,
            streaming: true,
          };

          recentMessages = recentMessages.map((message, messageIndex) =>
            messageIndex === index ? updatedMessage : message
          );

          setTimeout(() => scrollToBottomIfNeeded(), 0);
        }
      }
    } else if (data.action === 'error') {
      errorMessage = data.message;
      setTimeout(() => (errorMessage = null), 5000);
    }
  },
  (data) => {
    // existing streaming_end logic (lines 531-549)
    if (data.id) {
      if (streamingThinking[data.id]) {
        delete streamingThinking[data.id];
        streamingThinking = { ...streamingThinking };
      }

      const index = recentMessages.findIndex((m) => m.id === data.id);
      if (index !== -1) {
        recentMessages = recentMessages.map((message, messageIndex) =>
          messageIndex === index ? { ...message, streaming: false } : message
        );
      }
    }
  },
  (data) => {
    // NEW: handle current_state
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
  }
);
```

- [ ] Add third callback to `streamingSync` call for `current_state` handling

## Testing Strategy

### Unit Tests

- [x] Test that `SyncChannel#deliver_current_state_if_streaming` transmits for streaming messages
- [x] Test that it does not transmit for non-streaming messages
- [x] Test that the transmit includes correct content and thinking fields

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

The guard `recentMessages[index].streaming` ensures we only update messages that are still streaming. If streaming already ended, the update is ignored.

## Files Changed

| File | Change |
|------|--------|
| `app/channels/sync_channel.rb` | Add `deliver_current_state_if_streaming` method (~10 lines) |
| `app/frontend/lib/cable.js` | Refactor to event map pattern (~10 lines) |
| `app/frontend/lib/use-sync.js` | Extend `streamingSync` with optional third callback (~15 lines) |
| `app/frontend/pages/chats/show.svelte` | Add third callback to `streamingSync` call (~15 lines) |

## Implementation Checklist

### Backend
- [x] Add `deliver_current_state_if_streaming` private method to `SyncChannel`
- [x] Call the method after `stream_from` in `subscribed`
- [x] Add channel test for `current_state` transmission

### Frontend
- [ ] Refactor `handleStreamingUpdate` to event map pattern in `cable.js`
- [ ] Update `streamingSync` to accept optional third callback in `use-sync.js`
- [ ] Add third callback to `streamingSync` call in `show.svelte`
- [ ] Test manually on various network conditions

### Testing
- [x] Unit test SyncChannel transmit behavior
- [ ] Integration test full streaming flow
- [ ] Manual testing checklist complete
