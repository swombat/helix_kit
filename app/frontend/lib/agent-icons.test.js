import { describe, expect, it } from 'vitest';
import { agentIconComponents, agentIconFor } from './agent-icons';

describe('agent icon helpers', () => {
  it('returns configured icons with Robot as fallback', () => {
    expect(agentIconFor('Brain')).toBe(agentIconComponents.Brain);
    expect(agentIconFor('NotAnIcon')).toBe(agentIconComponents.Robot);
    expect(agentIconFor(null)).toBe(agentIconComponents.Robot);
  });
});
