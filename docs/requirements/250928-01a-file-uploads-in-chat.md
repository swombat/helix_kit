Ok, so currently we have a decent chat system... but it does not support file uploads.

RubyLLM supports attaching files and images and even audio files, as documented at: https://rubyllm.com/chat/#multi-modal-conversations

Please design a spec for adding file uploads to the chat system.

This should be done by either dragging and dropping files into the message input field, or by clicking a paperclip button in the message input field.

The file should be uploaded directly to S3 if that's possible (this would be possible with Turbo - not sure how easy it is in Svelte...) and then passed to RubyLLM for processing.

Files should be attached to a specific message (which then links them to a chat and to an account).

When a file is attached to a message sent by the user, the file should be displayed in the message display field (in the chat window that shows the whole conversation) with an appropriate icon.