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

export function tokenWarningLevel(contextTokens = 0, thresholds = {}) {
  if (contextTokens >= thresholds.critical) return 'critical';
  if (contextTokens >= thresholds.red) return 'red';
  if (contextTokens >= thresholds.amber) return 'amber';
  return null;
}

/**
 * Lookup a human-readable tooltip for a reasoning skip reason.
 * Prefer the backend-provided `reasoning_skip_reason_label` on the message JSON
 * when available; this helper exists as a fallback.
 */
const REASONING_SKIP_LABELS = {
  legacy_no_signature: 'Thinking unavailable: this turn was created before signed thinking blocks were stored.',
  tool_continuity_missing: 'Thinking degraded: an earlier tool call is missing continuity metadata.',
  provider_unsupported: 'Thinking unavailable for this turn.',
  anthropic_key_unavailable: 'Thinking unavailable: Anthropic API key not configured.',
};

export function reasoningSkipTooltip(reason) {
  return REASONING_SKIP_LABELS[reason] || 'Thinking was unavailable for this message.';
}
