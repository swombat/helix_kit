import { describe, expect, it } from 'vitest';
import { MESSAGE_TELEMETRY_FIELDS, formatCompactTelemetryTokens, formatTelemetryTokens } from './message-telemetry';

describe('message telemetry', () => {
  it('defines the four RubyLLM token categories in display order', () => {
    expect(MESSAGE_TELEMETRY_FIELDS).toEqual([
      ['input_tokens', 'Input'],
      ['output_tokens', 'Output'],
      ['cache_read_tokens', 'Cache read'],
      ['cache_write_tokens', 'Cache write'],
    ]);
  });

  it('formats known values and preserves unknown values as unavailable', () => {
    expect(formatTelemetryTokens(123456)).toBe('123,456');
    expect(formatTelemetryTokens(0)).toBe('0');
    expect(formatTelemetryTokens(null)).toBe('—');
    expect(formatTelemetryTokens(undefined)).toBe('—');
  });

  it('formats compact headline values without turning missing telemetry into zero', () => {
    expect(formatCompactTelemetryTokens(123456)).toBe('123.5k');
    expect(formatCompactTelemetryTokens(1000)).toBe('1k');
    expect(formatCompactTelemetryTokens(0)).toBe('0');
    expect(formatCompactTelemetryTokens(null)).toBe('—');
  });
});
