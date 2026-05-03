import { describe, expect, it } from 'vitest';
import { formatTokenCount, reasoningSkipTooltip, tokenWarningLevel } from './chat-utils';

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

  it('classifies token warning levels from active context thresholds', () => {
    const thresholds = { amber: 100_000, red: 150_000, critical: 200_000 };

    expect(tokenWarningLevel(99_999, thresholds)).toBeNull();
    expect(tokenWarningLevel(100_000, thresholds)).toBe('amber');
    expect(tokenWarningLevel(150_000, thresholds)).toBe('red');
    expect(tokenWarningLevel(200_000, thresholds)).toBe('critical');
  });
});
