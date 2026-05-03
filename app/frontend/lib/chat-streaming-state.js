export function applyStreamingUpdate({ messages, streamingThinking }, data) {
  if (!data.id) return { messages, streamingThinking, handled: false };

  const index = messages.findIndex((message) => message.id === data.id);
  if (index === -1) return { messages, streamingThinking, handled: false };

  if (data.action === 'thinking_update') {
    return {
      messages,
      streamingThinking: {
        ...streamingThinking,
        [data.id]: `${streamingThinking[data.id] || ''}${data.chunk || ''}`,
      },
      handled: true,
    };
  }

  if (data.action === 'streaming_update') {
    return {
      messages: messages.map((message, messageIndex) =>
        messageIndex === index
          ? {
              ...message,
              content: `${message.content || ''}${data.chunk || ''}`,
              streaming: true,
            }
          : message
      ),
      streamingThinking,
      handled: true,
    };
  }

  return { messages, streamingThinking, handled: false };
}

export function applyStreamingEnd({ messages, streamingThinking }, data) {
  if (!data.id) return { messages, streamingThinking, handled: false };

  const nextThinking = { ...streamingThinking };
  delete nextThinking[data.id];

  return {
    messages: messages.map((message) => (message.id === data.id ? { ...message, streaming: false } : message)),
    streamingThinking: nextThinking,
    handled: messages.some((message) => message.id === data.id) || streamingThinking[data.id] !== undefined,
  };
}
