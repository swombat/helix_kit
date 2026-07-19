export const MESSAGE_TELEMETRY_FIELDS = [
  ['input_tokens', 'Input'],
  ['output_tokens', 'Output'],
  ['cache_read_tokens', 'Cache read'],
  ['cache_write_tokens', 'Cache write'],
];

export function formatTelemetryTokens(value) {
  return value === null || value === undefined ? '—' : new Intl.NumberFormat('en-US').format(value);
}

export function formatCompactTelemetryTokens(value) {
  if (value === null || value === undefined) return '—';
  if (value >= 1000) return `${(value / 1000).toFixed(1).replace(/\.0$/, '')}k`;
  return value.toString();
}
