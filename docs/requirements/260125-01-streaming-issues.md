Here's the problem:

Very often, by the time the "message" object is created on the Svelte front end (to receive the streaming updates), the streaming is already under way, and so a bunch of messages get missed.

This leads to the message appearing wrong until it finishes streaming, when a full message update is requested by the frontend (as it comes out of streaming mode). This is a janky user experience.

Please think about this problem and come up with an elegant solution.

## Clarifications

### Transport & Architecture
- **Streaming transport**: ActionCable WebSockets (via Solid Cable)
- **Backend behavior**: Immediate broadcast - backend doesn't wait for frontend readiness
- **Trigger flow**: Fully async - user request queues a background job, job handles LLM call + streaming

### Message Creation Flow
- **Frontend message object**: Created from Inertia props update (backend creates message, Inertia pushes to frontend)
- **Race condition**: By the time Inertia props reach the frontend and the message component subscribes to ActionCable, streaming may already be in progress

### UX Impact
- **Visual jank**: Content appears suddenly or jumps during streaming
- **Missing content**: Parts of the message are missing until the final refresh
- **Final jump**: Jarring update when streaming ends and full message loads

### Consistency Requirements
- **Eventually consistent is acceptable**: It's okay if there are gaps during streaming, as long as the final message is correct
- **Current fallback**: Frontend requests full message update when streaming ends (this works, but the experience is janky)