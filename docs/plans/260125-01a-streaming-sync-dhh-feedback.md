# DHH Review: Streaming Race Condition Fix

## Overall Assessment

**Verdict: Over-engineered. The solution adds complexity where Rails already provides the answer.**

The spec proposes a "snapshot-on-subscribe" pattern that introduces a new API endpoint, a new subscription function, new hooks, new state tracking, and callback-based coordination. This is exactly the kind of JavaScript-driven architecture that fights Rails instead of embracing it. The frontend is doing work that belongs on the server.

The fundamental insight is correct: chunks get lost between message creation and subscription. But the solution reaches for client-side complexity when a server-side embrace of eventual consistency would be simpler.

## Critical Issues

### 1. The Snapshot Endpoint is a Code Smell

```ruby
def snapshot
  @message = Message.find(params[:id])
  # ... authorization ...
  render json: {
    content: @message.content,
    streaming: @message.streaming,
    thinking: @message.thinking_text
  }
end
```

This endpoint exists solely to work around a timing problem. It duplicates data that Inertia already delivers. When you find yourself adding API endpoints to compensate for race conditions in your real-time layer, you are solving the wrong problem.

The message already arrives via Inertia props. If the content is stale by the time the subscription connects, the answer is not "fetch it again" - the answer is "the subscription should deliver current state."

### 2. Callback Soup in JavaScript

The proposed `subscribeToStreamingMessage` function is a callback-driven monstrosity:

```javascript
subscribeToStreamingMessage(
  messageId,
  onSnapshot,   // callback 1
  onChunk,      // callback 2
  onEnd         // callback 3
)
```

Three callbacks. A content buffer. A `hasSnapshot` flag. Race condition handling between snapshot fetch and chunk arrival. This is the kind of JavaScript that makes developers weep.

Compare to the current approach: a simple event dispatch that any component can listen to. Clean. Decoupled. Rails-like in its simplicity.

### 3. State Synchronization Hell

```javascript
let streamingMessages = $state({});
// ...
streamingMessages[streamingMessageId] = { content: snapshot.content || '', thinking: snapshot.thinking || '' };
streamingMessages = { ...streamingMessages };
```

Now we have TWO sources of truth: `recentMessages` (from Inertia) and `streamingMessages` (from the snapshot). The spec requires a `getDisplayContent()` function to reconcile them. This is exactly the complexity that Inertia was designed to eliminate.

### 4. The Real Problem is Architectural

The spec correctly identifies that chunks are lost between message creation and subscription. But it then solves this at the wrong layer. The real question is: **why does the frontend need to catch every chunk?**

The answer is: it does not. The message content is persisted in the database. The frontend already reloads via Inertia when streaming ends. The "jank" is cosmetic, not correctional.

## A Simpler Solution: Embrace the Database

The existing architecture already has the right primitives:

1. `Message#stream_content` writes to the database with every chunk
2. The frontend subscribes to message updates
3. On `streaming_end`, Inertia reloads and gets the final state

The "jank" occurs because the frontend starts from empty and jumps to the final content. The fix is not to add snapshots - it is to **start from the Inertia-provided content**.

### The Three-Line Fix

The current code does this:

```javascript
// In streamingSync
const updatedMessage = {
  ...currentMessage,
  content: `${currentMessage.content || ''}${data.chunk || ''}`,
  streaming: true,
};
```

The problem: if the subscription misses early chunks, `currentMessage.content` starts from whatever Inertia delivered (possibly empty or stale).

The fix is architectural, not mechanical: **ensure Inertia delivers current content before any streaming events can modify it.**

This is already how it works. The race condition is:
1. Inertia delivers message with empty content
2. Backend starts streaming, broadcasts chunks 1-3
3. Frontend subscribes, receives chunks 4+
4. Content shows chunks 4+ only

But look: the Inertia props already have the message. The subscription already connects to `Message:${id}`. The missing piece is that **when the subscription connects, it should receive current database state**.

### The Rails Way: Use Turbo Streams or Server-Delivered State

Instead of fetching a snapshot, the subscription connection itself should include current state. ActionCable supports this natively via `transmit` in the `subscribed` callback:

```ruby
# app/channels/sync_channel.rb
def subscribed
  # ... existing authorization ...

  stream_from "#{params[:model]}:#{params[:id]}"

  # For streaming messages, send current state on connect
  if params[:model] == 'Message' && @model&.streaming?
    transmit(
      action: 'current_state',
      content: @model.content,
      thinking: @model.thinking_text
    )
  end
end
```

Now the frontend receives current state as soon as it subscribes. No new endpoint. No callback soup. No dual state tracking. The channel does what channels should do: establish synchronized state.

```javascript
received(data) {
  if (data.action === 'current_state') {
    // Initialize from server-sent state on connect
    updateMessageContent(data.id, data.content);
  } else if (data.action === 'streaming_update') {
    appendChunk(data.id, data.chunk);
  }
}
```

## What Works Well

The spec correctly identifies:

1. The race condition is real and causes user-visible jank
2. Eventually consistent is acceptable
3. The existing fallback (reload on streaming end) ensures correctness
4. Authorization should use associations, not new patterns

The problem statement is excellent. The solution overshoots.

## Improvements Needed

### 1. Kill the Snapshot Endpoint

No new endpoints. The data is already in the database. ActionCable can deliver it.

### 2. Use ActionCable's Built-in State Delivery

```ruby
# In SyncChannel#subscribed, after authorization:
if streaming_message?
  transmit_current_state(@model)
end

private

def streaming_message?
  params[:model] == 'Message' && @model&.streaming?
end

def transmit_current_state(message)
  transmit(
    action: 'current_state',
    id: message.to_param,
    content: message.content,
    thinking: message.thinking_text
  )
end
```

### 3. Simplify the Frontend

Keep the existing `streamingSync` function. Add handling for `current_state`:

```javascript
if (data.action === 'current_state') {
  // Replace content from Inertia with current database state
  const index = recentMessages.findIndex(m => m.id === data.id);
  if (index !== -1 && recentMessages[index].streaming) {
    recentMessages[index].content = data.content;
    recentMessages = [...recentMessages];
  }
}
```

No new functions. No new hooks. No new state objects. Just handle a new action type.

### 4. Remove the Dual State

There should be one source of truth: `recentMessages`. The streaming updates mutate it directly. The Inertia reload replaces it. No `streamingMessages` object. No `getDisplayContent()` indirection.

## Refactored Solution

### Backend Changes

```ruby
# app/channels/sync_channel.rb
def subscribed
  # ... existing code ...

  stream_from "#{params[:model]}:#{params[:id]}"

  deliver_current_state_if_streaming
end

private

def deliver_current_state_if_streaming
  return unless params[:model] == 'Message'
  return unless @model&.streaming?

  transmit(
    action: 'current_state',
    id: @model.to_param,
    content: @model.content,
    thinking: @model.thinking_text
  )
end
```

### Frontend Changes

```javascript
// In cable.js handleStreamingUpdate
if (data.action === 'current_state') {
  window.dispatchEvent(new CustomEvent('streaming-state', { detail: data }));
  return true;
}
```

```javascript
// In show.svelte's streamingSync, add a third listener
window.addEventListener('streaming-state', (event) => {
  const data = event.detail;
  if (data.id) {
    const index = recentMessages.findIndex(m => m.id === data.id);
    if (index !== -1) {
      recentMessages[index] = {
        ...recentMessages[index],
        content: data.content,
        thinking: data.thinking
      };
      recentMessages = [...recentMessages];
    }
  }
});
```

**Total changes:**
- One new method in `SyncChannel` (5 lines)
- One new case in `handleStreamingUpdate` (3 lines)
- One new event listener in `show.svelte` (10 lines)

No new endpoints. No new hooks. No callback soup. No dual state. The Rails Way.

## Testing

The refactored solution needs only:
- Test that `SyncChannel` transmits current state for streaming messages
- Test that `SyncChannel` does not transmit for non-streaming messages
- Test that the frontend handles `streaming-state` events correctly

The original spec proposed 20+ test cases. This approach needs 3.

## Conclusion

The proposed spec solves a real problem with an over-engineered solution. It adds an endpoint, a function, a hook, new state, and callback coordination. It creates dual sources of truth and requires reconciliation logic.

The simpler solution uses ActionCable as it was designed: the server delivers state when the client connects. One method, one event handler, done.

DHH would ask: "Why are we writing JavaScript to fetch data that the server already knows?" The answer is: we should not be.

**Recommendation: Reject the spec as written. Implement the server-side state delivery pattern instead.**
