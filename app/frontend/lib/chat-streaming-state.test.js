import { describe, expect, test } from 'vitest';
import { applyStreamingEnd, applyStreamingUpdate } from './chat-streaming-state';

describe('chat streaming state', () => {
  test('appends thinking chunks by message id without changing message content', () => {
    const messages = [{ id: 1, content: '', streaming: true }];
    const result = applyStreamingUpdate(
      { messages, streamingThinking: { 1: 'step one' } },
      { id: 1, action: 'thinking_update', chunk: ' then step two' }
    );

    expect(result.streamingThinking[1]).toBe('step one then step two');
    expect(result.messages).toBe(messages);
  });

  test('appends streamed content and marks the message as streaming', () => {
    const result = applyStreamingUpdate(
      { messages: [{ id: 1, content: 'Hello', streaming: false }], streamingThinking: {} },
      { id: 1, action: 'streaming_update', chunk: ' world' }
    );

    expect(result.messages[0]).toMatchObject({ content: 'Hello world', streaming: true });
  });

  test('ignores updates for missing messages', () => {
    const messages = [{ id: 1, content: 'Hello' }];
    const result = applyStreamingUpdate(
      { messages, streamingThinking: {} },
      { id: 2, action: 'streaming_update', chunk: ' world' }
    );

    expect(result).toEqual({ messages, streamingThinking: {}, handled: false });
  });

  test('clears thinking and streaming state at stream end', () => {
    const result = applyStreamingEnd(
      { messages: [{ id: 1, content: 'Hello', streaming: true }], streamingThinking: { 1: 'thinking' } },
      { id: 1 }
    );

    expect(result.messages[0].streaming).toBe(false);
    expect(result.streamingThinking).toEqual({});
    expect(result.handled).toBe(true);
  });
});
