<script>
  import { ArrowCounterClockwise, BookOpen, Brain, Shield, ShieldCheck, Trash, Warning } from 'phosphor-svelte';
  import { journalMemoryOpacity } from '$lib/agent-memory';

  let { memory, ondelete, onundiscard, ontoggleProtected } = $props();
</script>

<div
  class="memory-card flex items-start gap-3 p-3 rounded-lg border
    {memory.expired ? 'border-dashed' : 'border-border'}
    {memory.discarded ? 'border-l-4 border-l-destructive opacity-60' : ''}"
  style="--memory-opacity: {memory.discarded ? 0.6 : journalMemoryOpacity(memory)}">
  <div class="flex-shrink-0 mt-0.5">
    {#if memory.memory_type === 'core'}
      <Brain size={18} class="text-primary" weight="duotone" />
    {:else}
      <BookOpen size={18} class="text-muted-foreground" weight="duotone" />
    {/if}
  </div>

  <div class="flex-1 min-w-0">
    <div class="flex items-center gap-2 mb-1">
      <span
        class="text-xs font-medium uppercase {memory.memory_type === 'core'
          ? 'text-primary'
          : 'text-muted-foreground'}">
        {memory.memory_type}
      </span>
      {#if memory.constitutional}
        <span class="text-xs font-medium uppercase text-primary flex items-center gap-0.5">
          <ShieldCheck size={10} weight="fill" /> protected
        </span>
      {/if}
      {#if memory.discarded}
        <span class="text-xs font-medium uppercase text-destructive">discarded</span>
      {/if}
      <span class="text-xs text-muted-foreground">{memory.created_at}</span>
      {#if memory.expired}
        <span class="text-xs text-warning flex items-center gap-1">
          <Warning size={12} /> expired
        </span>
      {/if}
    </div>
    <p class="text-sm whitespace-pre-wrap break-words">{memory.content}</p>
  </div>

  {#if memory.discarded}
    <button
      type="button"
      onclick={() => onundiscard?.(memory.id)}
      class="flex-shrink-0 p-1 text-muted-foreground hover:text-primary transition-colors"
      title="Restore memory">
      <ArrowCounterClockwise size={16} />
    </button>
  {:else}
    <button
      type="button"
      onclick={() => ontoggleProtected?.(memory.id, memory.constitutional)}
      class="flex-shrink-0 p-1 transition-colors {memory.constitutional
        ? 'text-primary'
        : 'text-muted-foreground hover:text-primary'}"
      title={memory.constitutional ? 'Constitutional (protected from deletion)' : 'Mark as constitutional'}>
      {#if memory.constitutional}
        <ShieldCheck size={16} weight="fill" />
      {:else}
        <Shield size={16} />
      {/if}
    </button>
    {#if !memory.constitutional}
      <button
        type="button"
        onclick={() => ondelete?.(memory.id)}
        class="flex-shrink-0 p-1 text-muted-foreground hover:text-destructive transition-colors">
        <Trash size={16} />
      </button>
    {/if}
  {/if}
</div>

<style>
  .memory-card {
    opacity: var(--memory-opacity, 1);
    transition: opacity 150ms ease-in-out;
  }

  .memory-card:hover {
    opacity: 1;
  }
</style>
