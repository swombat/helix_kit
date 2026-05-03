<script>
  import { Button } from '$lib/components/shadcn/button/index.js';
  import { Lightning, Plus } from 'phosphor-svelte';

  let { onInitiate, onCreate } = $props();
</script>

<div class="flex items-center justify-between mb-8">
  <div>
    <h1 class="text-3xl font-bold">Agents</h1>
    <p class="text-muted-foreground mt-1">Create and manage AI agents with custom personalities</p>
  </div>
  <div class="flex gap-2">
    <Button variant="outline" onclick={onInitiate}>
      <Lightning class="mr-2 size-4" />
      Trigger Initiation
    </Button>
    <Button onclick={onCreate}>
      <Plus class="mr-2 size-4" />
      New Agent
    </Button>
  </div>
</div>
