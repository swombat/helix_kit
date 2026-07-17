export const DEFAULT_SCROLL_THRESHOLD = 200;

export function combinePaginatedMessages(olderMessages = [], recentMessages = []) {
  const recentIds = new Set(recentMessages.map((message) => message.id));
  const seen = new Set(recentIds);

  const uniqueOlderMessages = olderMessages.filter((message) => {
    if (seen.has(message.id)) return false;
    seen.add(message.id);
    return true;
  });

  return [...uniqueOlderMessages, ...recentMessages];
}

export function shouldLoadMoreMessages(
  { scrollTop, hasMore, loadingMore, oldestId },
  threshold = DEFAULT_SCROLL_THRESHOLD
) {
  return scrollTop < threshold && Boolean(hasMore) && !loadingMore && Boolean(oldestId);
}

export function prependOlderMessages({ olderMessages = [], newMessages = [], hasMore, oldestId }) {
  return {
    olderMessages: combinePaginatedMessages(newMessages, olderMessages),
    hasMore,
    oldestId,
  };
}

export function preserveDisplacedRecentMessages({
  olderMessages = [],
  previousRecentMessages = [],
  recentMessages = [],
}) {
  if (previousRecentMessages.length === 0) return olderMessages;

  const currentIds = new Set(recentMessages.map((message) => message.id));
  const displacedMessages = previousRecentMessages.filter((message) => !currentIds.has(message.id));
  if (displacedMessages.length === 0) return olderMessages;

  return combinePaginatedMessages(olderMessages, displacedMessages);
}
