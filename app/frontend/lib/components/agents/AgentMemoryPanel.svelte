<script>
  import { Button } from '$lib/components/shadcn/button/index.js';
  import { Input } from '$lib/components/shadcn/input';
  import { Label } from '$lib/components/shadcn/label';
  import {
    Brain,
    BookOpen,
    Trash,
    Plus,
    ShieldCheck,
    Lightning,
    MagnifyingGlass,
    Hourglass,
    CaretDown,
  } from 'phosphor-svelte';
  import { filterMemories } from '$lib/agent-memory';
  import AgentMemoryCard from '$lib/components/agents/AgentMemoryCard.svelte';

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
  let newMemoryContent = $state('');
  let newMemoryType = $state('core');
  let memorySearch = $state('');
  let showCore = $state(true);
  let showJournal = $state(true);
  let showProtected = $state(true);
  let showDiscarded = $state(false);

  let filteredMemories = $derived.by(() => {
    return filterMemories(memories, { search: memorySearch, showCore, showJournal, showProtected, showDiscarded });
  });

  function resetNewMemoryForm() {
    newMemoryContent = '';
    newMemoryType = 'core';
    showNewMemoryForm = false;
  }

  function createMemory() {
    if (!newMemoryContent.trim()) return;

    oncreate?.({
      content: newMemoryContent,
      memoryType: newMemoryType,
    });
    resetNewMemoryForm();
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
    <div class="p-4 border rounded-lg bg-muted/30 space-y-4">
      <div class="space-y-2">
        <Label for="new_memory_content">Memory Content</Label>
        <textarea
          id="new_memory_content"
          bind:value={newMemoryContent}
          placeholder="Enter the memory content..."
          rows="3"
          class="w-full resize-none border border-input rounded-md px-3 py-2 text-sm bg-background
                 focus:outline-none focus:ring-2 focus:ring-ring focus:border-transparent"></textarea>
      </div>
      <div class="space-y-2">
        <Label>Memory Type</Label>
        <div class="flex gap-4">
          <label class="flex items-center gap-2 cursor-pointer">
            <input type="radio" name="memory_type" value="core" bind:group={newMemoryType} class="w-4 h-4" />
            <Brain size={16} class="text-primary" weight="duotone" />
            <span class="text-sm">Core (permanent)</span>
          </label>
          <label class="flex items-center gap-2 cursor-pointer">
            <input type="radio" name="memory_type" value="journal" bind:group={newMemoryType} class="w-4 h-4" />
            <BookOpen size={16} class="text-muted-foreground" weight="duotone" />
            <span class="text-sm">Journal (expires in 1 week)</span>
          </label>
        </div>
      </div>
      <div class="flex gap-2 justify-end">
        <Button type="button" variant="outline" size="sm" onclick={resetNewMemoryForm}>Cancel</Button>
        <Button type="button" size="sm" onclick={createMemory} disabled={!newMemoryContent.trim()}>Save Memory</Button>
      </div>
    </div>
  {/if}

  {#if memories.length === 0 && !showNewMemoryForm}
    <p class="text-sm text-muted-foreground">
      This agent has no memories yet. Click "Add Memory" to create one manually, or memories will appear here as the
      agent creates them using the save_memory tool.
    </p>
  {:else if memories.length > 0}
    <div class="flex flex-col sm:flex-row gap-3 items-start sm:items-center">
      <div class="relative flex-1 w-full sm:w-auto">
        <MagnifyingGlass size={16} class="absolute left-2.5 top-1/2 -translate-y-1/2 text-muted-foreground" />
        <Input type="text" placeholder="Search memories..." bind:value={memorySearch} class="pl-8" />
      </div>
      <div class="flex gap-3">
        <label class="flex items-center gap-1.5 cursor-pointer text-sm" title="Core">
          <input type="checkbox" bind:checked={showCore} class="w-3.5 h-3.5 rounded" />
          <Brain size={14} weight="duotone" class="lg:hidden text-primary" />
          <span class="hidden lg:inline">Core</span>
        </label>
        <label class="flex items-center gap-1.5 cursor-pointer text-sm" title="Journal">
          <input type="checkbox" bind:checked={showJournal} class="w-3.5 h-3.5 rounded" />
          <BookOpen size={14} weight="duotone" class="lg:hidden text-muted-foreground" />
          <span class="hidden lg:inline">Journal</span>
        </label>
        <label class="flex items-center gap-1.5 cursor-pointer text-sm" title="Protected">
          <input type="checkbox" bind:checked={showProtected} class="w-3.5 h-3.5 rounded" />
          <ShieldCheck size={14} weight="duotone" class="lg:hidden text-primary" />
          <span class="hidden lg:inline">Protected</span>
        </label>
        <label class="flex items-center gap-1.5 cursor-pointer text-sm" title="Discarded">
          <input type="checkbox" bind:checked={showDiscarded} class="w-3.5 h-3.5 rounded" />
          <Trash size={14} weight="duotone" class="lg:hidden text-destructive" />
          <span class="hidden lg:inline">Discarded</span>
        </label>
      </div>
    </div>

    {#if filteredMemories.length === 0}
      <p class="text-sm text-muted-foreground py-4">No memories match your filters.</p>
    {:else}
      <div class="text-xs text-muted-foreground flex flex-wrap items-center gap-x-3 gap-y-0.5">
        <span>Showing {filteredMemories.length} of {memories.length} memories</span>
        {#if agent.memory_token_summary}
          {@const mts = agent.memory_token_summary}
          <span class="flex items-center gap-1">
            <Brain size={12} weight="duotone" class="lg:hidden text-primary" />
            <span class="hidden lg:inline font-medium">Core:</span>
            {mts.core.toLocaleString()}t
          </span>
          <span class="flex items-center gap-1">
            <BookOpen size={12} weight="duotone" class="lg:hidden text-muted-foreground" />
            <span class="hidden lg:inline font-medium">Journal:</span>
            {mts.active_journal.toLocaleString()}t
          </span>
          {#if mts.inactive_journal > 0}
            <span class="flex items-center gap-1 opacity-50">
              <Hourglass size={12} weight="duotone" class="lg:hidden" />
              <span class="hidden lg:inline font-medium">Inactive:</span>
              {mts.inactive_journal.toLocaleString()}t
            </span>
          {/if}
        {/if}
      </div>
    {/if}

    <div class="space-y-3 max-h-[32rem] overflow-y-auto">
      {#each filteredMemories as memory (memory.id)}
        <AgentMemoryCard {memory} {ondelete} {onundiscard} {ontoggleProtected} />
      {/each}
    </div>
  {/if}
</div>
