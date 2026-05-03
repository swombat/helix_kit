import { describe, expect, it } from 'vitest';
import { filterMemories, journalMemoryOpacity } from './agent-memory';

describe('agent memory helpers', () => {
  const memories = [
    { id: 1, memory_type: 'core', constitutional: false, discarded: false, content: 'Keeps project context' },
    { id: 2, memory_type: 'core', constitutional: true, discarded: false, content: 'Protected preference' },
    { id: 3, memory_type: 'journal', constitutional: false, discarded: false, content: 'Temporary note' },
    { id: 4, memory_type: 'journal', constitutional: false, discarded: true, content: 'Discarded note' },
  ];

  it('filters memories by type, protection, discard state, and search', () => {
    expect(filterMemories(memories).map((memory) => memory.id)).toEqual([1, 2, 3]);
    expect(filterMemories(memories, { showCore: false }).map((memory) => memory.id)).toEqual([2, 3]);
    expect(filterMemories(memories, { showProtected: false }).map((memory) => memory.id)).toEqual([1, 3]);
    expect(filterMemories(memories, { showJournal: false }).map((memory) => memory.id)).toEqual([1, 2]);
    expect(filterMemories(memories, { showDiscarded: true }).map((memory) => memory.id)).toEqual([1, 2, 3, 4]);
    expect(filterMemories(memories, { search: 'PROJECT' }).map((memory) => memory.id)).toEqual([1]);
  });

  it('calculates journal opacity with a floor', () => {
    expect(journalMemoryOpacity({ memory_type: 'core' })).toBe(1);
    expect(journalMemoryOpacity({ memory_type: 'journal', expired: true })).toBe(0.3);
    expect(journalMemoryOpacity({ memory_type: 'journal', age_in_days: 2 })).toBe(0.8);
    expect(journalMemoryOpacity({ memory_type: 'journal', age_in_days: 20 })).toBe(0.3);
  });
});
