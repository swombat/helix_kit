export const DEFAULT_SCROLL_THRESHOLD = 200;

export function combinePaginatedMessages(olderMessages = [], recentMessages = []) {
  const seen = new Set();

  return [...olderMessages, ...recentMessages].filter((message) => {
    if (seen.has(message.id)) return false;
    seen.add(message.id);
    return true;
  });
}

export function shouldLoadMoreMessages(
  { scrollTop, hasMore, loadingMore, oldestId },
  threshold = DEFAULT_SCROLL_THRESHOLD
) {
  return scrollTop < threshold && Boolean(hasMore) && !loadingMore && Boolean(oldestId);
}

export function prependOlderMessages({ olderMessages = [], newMessages = [], hasMore, oldestId }) {
  return {
    olderMessages: [...newMessages, ...olderMessages],
    hasMore,
    oldestId,
  };
}
