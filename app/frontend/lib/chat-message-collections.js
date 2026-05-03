export function patchMessageInCollections({ recentMessages = [], olderMessages = [], messageId, patch = {} }) {
  return {
    recentMessages: recentMessages.map((message) => (message.id === messageId ? { ...message, ...patch } : message)),
    olderMessages: olderMessages.map((message) => (message.id === messageId ? { ...message, ...patch } : message)),
  };
}

export function removeMessageFromCollections({ recentMessages = [], olderMessages = [], messageId }) {
  return {
    recentMessages: recentMessages.filter((message) => message.id !== messageId),
    olderMessages: olderMessages.filter((message) => message.id !== messageId),
  };
}

export function appendMessageIfMissing(messages = [], message) {
  if (!message?.id) return messages;
  if (messages.some((existingMessage) => existingMessage.id === message.id)) return messages;

  return [...messages, message];
}
