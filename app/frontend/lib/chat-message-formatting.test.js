import { describe, expect, test } from 'vitest';
import { formatToolsUsed } from './chat-message-formatting';

describe('formatToolsUsed', () => {
  test('normalizes legacy tool strings, URLs, and plain labels', () => {
    expect(formatToolsUsed(['#<RubyLLM/tool call:0x123>', 'https://docs.maestro.dev/get-started', 'Search'])).toEqual([
      'Web access',
      'docs.maestro.dev',
      'Search',
    ]);
  });

  test('handles empty values', () => {
    expect(formatToolsUsed(null)).toEqual([]);
    expect(formatToolsUsed([])).toEqual([]);
  });
});
