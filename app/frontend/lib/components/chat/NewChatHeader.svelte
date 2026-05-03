<script>
  import { Button } from '$lib/components/shadcn/button/index.js';
  import ChatTargetSelect from '$lib/components/chat/ChatTargetSelect.svelte';
  import { List } from 'phosphor-svelte';

  let {
    models = [],
    agents = [],
    selectedModel = $bindable(''),
    selectedAgent = $bindable(null),
    onAgentSelected,
    onMenuOpen,
  } = $props();
</script>

<header class="border-b border-border bg-muted/30 px-4 md:px-6 py-3 md:py-4">
  <div class="flex items-center gap-3">
    <Button variant="ghost" size="sm" onclick={onMenuOpen} class="h-8 w-8 p-0 md:hidden">
      <List size={20} />
    </Button>
    <h1 class="text-lg font-semibold">New Chat</h1>
  </div>
  <div class="mt-2 ml-0 md:ml-0">
    <ChatTargetSelect {models} {agents} bind:selectedModel bind:selectedAgent {onAgentSelected} />
  </div>
</header>
