<script>
  import { Button } from '$lib/components/shadcn/button/index.js';
  import { CaretDown, Lightning, Plus } from 'phosphor-svelte';
  import { filterMemories } from '$lib/agent-memory';
  import AgentMemoryCard from '$lib/components/agents/AgentMemoryCard.svelte';
  import AgentMemoryFilters from '$lib/components/agents/AgentMemoryFilters.svelte';
  import AgentMemorySummary from '$lib/components/agents/AgentMemorySummary.svelte';
  import AgentNewMemoryForm from '$lib/components/agents/AgentNewMemoryForm.svelte';

  let {
    agent,
    memories = [],
    triggeringRefinement = false,
    onrefine,
    oncreate,
    ondelete,
    onundiscard,
    ontoggleProtected,
  } = $props();

  let showRefinementMenu = $state(false);
  let showNewMemoryForm = $state(false);
  let memorySearch = $state('');
  let showCore = $state(true);
  let showJournal = $state(true);
  let showProtected = $state(true);
  let showDiscarded = $state(false);

  let filteredMemories = $derived.by(() => {
    return filterMemories(memories, { search: memorySearch, showCore, showJournal, showProtected, showDiscarded });
  });

  function createMemory(memory) {
    oncreate?.(memory);
    showNewMemoryForm = false;
  }

  function refine(mode) {
    showRefinementMenu = false;
    onrefine?.(mode);
  }
</script>

<div class="space-y-6">
  <div class="flex flex-col sm:flex-row sm:items-start sm:justify-between gap-3">
    <div>
      <h2 class="text-lg font-semibold">Agent Memory</h2>
      <p class="text-sm text-muted-foreground">
        Review and manage this agent's memories. Core memories are permanent; journal entries fade after a week.
      </p>
    </div>
    <div class="flex flex-col sm:flex-row gap-2">
      <div class="relative">
        <Button
          type="button"
          variant="outline"
          size="sm"
          disabled={triggeringRefinement}
          onclick={() => (showRefinementMenu = !showRefinementMenu)}>
          <Lightning class="size-4 mr-1" />
          {triggeringRefinement ? 'Queuing...' : 'Refine'}
          <CaretDown class="size-3.5 ml-1" />
        </Button>
        {#if showRefinementMenu}
          <!-- svelte-ignore a11y_no_static_element_interactions -->
          <div
            class="fixed inset-0 z-10"
            onclick={() => (showRefinementMenu = false)}
            onkeydown={(event) => event.key === 'Escape' && (showRefinementMenu = false)}>
          </div>
          <div
            class="absolute right-0 top-full mt-1 bg-popover border border-border rounded-md shadow-md z-20 py-1 min-w-[160px]">
            <button
              type="button"
              class="w-full text-left px-3 py-1.5 text-sm hover:bg-muted transition-colors"
              onclick={() => refine('full')}>
              Full Refinement
            </button>
            <button
              type="button"
              class="w-full text-left px-3 py-1.5 text-sm hover:bg-muted transition-colors"
              onclick={() => refine('dedup_only')}>
              Dedup Only
            </button>
          </div>
        {/if}
      </div>
      {#if !showNewMemoryForm}
        <Button type="button" variant="outline" size="sm" onclick={() => (showNewMemoryForm = true)}>
          <Plus class="size-4 mr-1" />
          Add Memory
        </Button>
      {/if}
    </div>
  </div>

  {#if showNewMemoryForm}
    <AgentNewMemoryForm oncreate={createMemory} oncancel={() => (showNewMemoryForm = false)} />
  {/if}

  {#if memories.length === 0 && !showNewMemoryForm}
    <p class="text-sm text-muted-foreground">
      This agent has no memories yet. Click "Add Memory" to create one manually, or memories will appear here as the
      agent creates them using the save_memory tool.
    </p>
  {:else if memories.length > 0}
    <AgentMemoryFilters bind:memorySearch bind:showCore bind:showJournal bind:showProtected bind:showDiscarded />

    {#if filteredMemories.length === 0}
      <p class="text-sm text-muted-foreground py-4">No memories match your filters.</p>
    {:else}
      <AgentMemorySummary
        filteredCount={filteredMemories.length}
        totalCount={memories.length}
        memoryTokenSummary={agent.memory_token_summary} />
    {/if}

    <div class="space-y-3 max-h-[32rem] overflow-y-auto">
      {#each filteredMemories as memory (memory.id)}
        <AgentMemoryCard {memory} {ondelete} {onundiscard} {ontoggleProtected} />
      {/each}
    </div>
  {/if}
</div>
