<script>
  import { BookOpen, Brain, Hourglass } from 'phosphor-svelte';

  let { filteredCount, totalCount, memoryTokenSummary = null } = $props();
</script>

<div class="text-xs text-muted-foreground flex flex-wrap items-center gap-x-3 gap-y-0.5">
  <span>Showing {filteredCount} of {totalCount} memories</span>
  {#if memoryTokenSummary}
    <span class="flex items-center gap-1">
      <Brain size={12} weight="duotone" class="lg:hidden text-primary" />
      <span class="hidden lg:inline font-medium">Core:</span>
      {memoryTokenSummary.core.toLocaleString()}t
    </span>
    <span class="flex items-center gap-1">
      <BookOpen size={12} weight="duotone" class="lg:hidden text-muted-foreground" />
      <span class="hidden lg:inline font-medium">Journal:</span>
      {memoryTokenSummary.active_journal.toLocaleString()}t
    </span>
    {#if memoryTokenSummary.inactive_journal > 0}
      <span class="flex items-center gap-1 opacity-50">
        <Hourglass size={12} weight="duotone" class="lg:hidden" />
        <span class="hidden lg:inline font-medium">Inactive:</span>
        {memoryTokenSummary.inactive_journal.toLocaleString()}t
      </span>
    {/if}
  {/if}
</div>
