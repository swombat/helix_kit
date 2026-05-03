export function filterMemories(
  memories = [],
  { search = '', showCore = true, showJournal = true, showProtected = true, showDiscarded = false } = {}
) {
  const term = search.toLowerCase();

  return memories.filter((memory) => {
    if (memory.discarded && !showDiscarded) return false;
    if (memory.memory_type === 'core' && !memory.constitutional && !showCore) return false;
    if (memory.memory_type === 'journal' && !showJournal) return false;
    if (memory.constitutional && !showProtected) return false;
    if (term && !memory.content.toLowerCase().includes(term)) return false;
    return true;
  });
}

export function journalMemoryOpacity(memory) {
  if (memory.memory_type !== 'journal') return 1;
  if (memory.expired) return 0.3;
  return Math.max(0.3, 1 - memory.age_in_days * 0.1);
}
