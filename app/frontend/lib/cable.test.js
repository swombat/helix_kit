import { describe, expect, test, vi } from 'vitest';
import { debounce, streamingEventName } from './cable';

describe('cable helpers', () => {
  test('classifies streaming events without coupling tests to ActionCable', () => {
    expect(streamingEventName({ action: 'streaming_update' })).toBe('streaming-update');
    expect(streamingEventName({ action: 'thinking_update' })).toBe('streaming-update');
    expect(streamingEventName({ action: 'error' })).toBe('streaming-update');
    expect(streamingEventName({ action: 'streaming_end' })).toBe('streaming-end');
    expect(streamingEventName({ action: 'debug_log' })).toBe('debug-log');
    expect(streamingEventName({ action: 'chat_updated' })).toBeNull();
  });

  test('debounces reload props while preserving the union of requested props', () => {
    vi.useFakeTimers();
    const callback = vi.fn();
    const debounced = debounce(callback, 300);

    debounced(['chat']);
    debounced(['messages']);
    vi.advanceTimersByTime(299);
    expect(callback).not.toHaveBeenCalled();
    vi.advanceTimersByTime(1);

    expect(callback).toHaveBeenCalledWith(['chat', 'messages']);
    vi.useRealTimers();
  });
});
