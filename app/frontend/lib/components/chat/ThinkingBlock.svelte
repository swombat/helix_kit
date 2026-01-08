<script>
  import { slide } from 'svelte/transition';
  import { Brain } from 'phosphor-svelte';

  let { content = '', isStreaming = false, preview = '' } = $props();
  let expanded = $state(false);

  const displayPreview = $derived(preview || 'Thinking...');
</script>

<div class="mb-3 pb-3 border-b border-border/50">
  <button
    onclick={() => (expanded = !expanded)}
    class="flex items-center gap-2 text-sm text-muted-foreground hover:text-foreground transition-colors w-full text-left">
    <Brain size={16} weight="duotone" class="shrink-0 {isStreaming ? 'animate-pulse text-primary' : ''}" />
    {#if expanded}
      <span class="font-medium">Thinking</span>
      <span class="ml-auto text-xs">Click to collapse</span>
    {:else}
      <span class="truncate italic">{displayPreview}</span>
      <span class="ml-auto text-xs shrink-0">Click to expand</span>
    {/if}
  </button>

  {#if expanded}
    <div
      transition:slide={{ duration: 200 }}
      class="mt-2 pl-6 text-sm text-muted-foreground whitespace-pre-wrap font-mono bg-muted/30 rounded p-3 max-h-64 overflow-y-auto">
      {content}
      {#if isStreaming}
        <span class="animate-pulse">|</span>
      {/if}
    </div>
  {/if}
</div>
