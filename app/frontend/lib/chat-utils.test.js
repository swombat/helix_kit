import { describe, expect, it } from 'vitest';
import { formatTokenCount, reasoningSkipTooltip } from './chat-utils';

describe('chat utilities', () => {
  it('formats token counts for compact chat display', () => {
    expect(formatTokenCount(0)).toBe('0');
    expect(formatTokenCount(999)).toBe('999');
    expect(formatTokenCount(1000)).toBe('1k');
    expect(formatTokenCount(1250)).toBe('1.3k');
    expect(formatTokenCount(15300)).toBe('15.3k');
  });

  it('returns stable fallback copy for thinking skip reasons', () => {
    expect(reasoningSkipTooltip('legacy_no_signature')).toContain('created before signed thinking blocks');
    expect(reasoningSkipTooltip('anthropic_key_unavailable')).toContain('Anthropic API key not configured');
    expect(reasoningSkipTooltip('unknown_reason')).toBe('Thinking was unavailable for this message.');
  });
});
