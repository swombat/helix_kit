<script>
  import ChatTargetSelect from '$lib/components/chat/ChatTargetSelect.svelte';
  import { Globe, Robot, UsersThree } from 'phosphor-svelte';

  let {
    agents = [],
    models = [],
    selectedModel = $bindable(''),
    conversationMode = $bindable('model'),
    webAccess = $bindable(false),
  } = $props();

  function selectMode(mode) {
    conversationMode = mode;
    if (mode === 'agents') webAccess = false;
  }
</script>

<div class="border-b border-border px-4 md:px-6 py-2 bg-muted/10 flex flex-wrap items-center gap-3 md:gap-4">
  <div class="inline-flex rounded-md border border-border bg-background p-0.5">
    <button
      type="button"
      onclick={() => selectMode('model')}
      class="inline-flex items-center gap-2 rounded-sm px-3 py-1.5 text-sm transition-colors
             {conversationMode === 'model'
        ? 'bg-primary text-primary-foreground'
        : 'text-muted-foreground hover:bg-muted'}">
      <Robot size={16} weight="duotone" />
      Model
    </button>

    {#if agents.length > 0}
      <button
        type="button"
        onclick={() => selectMode('agents')}
        class="inline-flex items-center gap-2 rounded-sm px-3 py-1.5 text-sm transition-colors
               {conversationMode === 'agents'
          ? 'bg-primary text-primary-foreground'
          : 'text-muted-foreground hover:bg-muted'}">
        <UsersThree size={16} weight="duotone" />
        Agents
      </button>
    {/if}
  </div>

  {#if conversationMode === 'model'}
    <ChatTargetSelect {models} bind:selectedModel />

    <label class="flex items-center gap-2 cursor-pointer hover:opacity-80 transition-opacity w-fit">
      <input
        type="checkbox"
        bind:checked={webAccess}
        class="w-4 h-4 rounded border-gray-300 text-primary focus:ring-primary focus:ring-offset-0 focus:ring-2 transition-colors cursor-pointer" />
      <Globe size={16} class="text-muted-foreground" weight="duotone" />
      <span class="text-sm text-muted-foreground">Allow web access</span>
    </label>
  {/if}
</div>
