# AI Conversations on HelixKit

Ok, so we have the backend side of the RubyLLM integration working. Next, we need to implement the frontend side of the integration.

What I'd like it to do is to have a top-level items called "Chats", along with documentat/about.

In that screen, we want a typical "list of conversations" on the left, with a plus to add a new conversation. Don't bother paging them for now.

When an active chat is selected, the conversation pane enables you to send messages and view the conversation history. Don't bother with file/image uploads for version 1. Just enable written input.

When creating a chat you should have a model selector too. After the chat is created, no model input.

Importantly, we want to use the `dynamicSync` system to enable live streaming of the AI responses.

- The list of chats (`Account:ObfsId/chats`)
- The specific chat (`Chat:ObfsId`) (this will also return a list of messages with their contents)

Eventually this will be too cumbersome (to return the entire conversation history for each chat), so we'll need to implement a more efficient system. But for now just keep it simple.

I think the rest of the spec should be fairly easy to guess. This is just a chat system and there are millions of them. Ask any questions if this isn't clear though.