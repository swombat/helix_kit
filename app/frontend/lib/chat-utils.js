/**
 * Get the CSRF token from the meta tag.
 */
export function csrfToken() {
  return document.querySelector('meta[name="csrf-token"]')?.content || '';
}

/**
 * Format token count for display (e.g., 1.2k, 15.3k).
 */
export function formatTokenCount(count) {
  if (count >= 1000) {
    return (count / 1000).toFixed(1).replace(/\.0$/, '') + 'k';
  }
  return count.toString();
}
