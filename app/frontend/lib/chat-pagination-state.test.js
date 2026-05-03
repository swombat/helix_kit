import { describe, expect, test } from 'vitest';
import { combinePaginatedMessages, prependOlderMessages, shouldLoadMoreMessages } from './chat-pagination-state';

describe('chat pagination state', () => {
  test('combines older and recent messages while preserving the first copy of duplicates', () => {
    const olderMessages = [
      { id: 1, content: 'oldest' },
      { id: 2, content: 'older copy' },
    ];
    const recentMessages = [
      { id: 2, content: 'recent copy' },
      { id: 3, content: 'newest' },
    ];

    expect(combinePaginatedMessages(olderMessages, recentMessages)).toEqual([
      { id: 1, content: 'oldest' },
      { id: 2, content: 'older copy' },
      { id: 3, content: 'newest' },
    ]);
  });

  test('loads more only near the top when more messages are available and idle', () => {
    expect(shouldLoadMoreMessages({ scrollTop: 199, hasMore: true, loadingMore: false, oldestId: 123 })).toBe(true);
    expect(shouldLoadMoreMessages({ scrollTop: 200, hasMore: true, loadingMore: false, oldestId: 123 })).toBe(false);
    expect(shouldLoadMoreMessages({ scrollTop: 10, hasMore: false, loadingMore: false, oldestId: 123 })).toBe(false);
    expect(shouldLoadMoreMessages({ scrollTop: 10, hasMore: true, loadingMore: true, oldestId: 123 })).toBe(false);
    expect(shouldLoadMoreMessages({ scrollTop: 10, hasMore: true, loadingMore: false, oldestId: null })).toBe(false);
  });

  test('prepends fetched messages and carries pagination metadata forward', () => {
    expect(
      prependOlderMessages({
        olderMessages: [{ id: 3 }],
        newMessages: [{ id: 1 }, { id: 2 }],
        hasMore: true,
        oldestId: 1,
      })
    ).toEqual({
      olderMessages: [{ id: 1 }, { id: 2 }, { id: 3 }],
      hasMore: true,
      oldestId: 1,
    });
  });
});
