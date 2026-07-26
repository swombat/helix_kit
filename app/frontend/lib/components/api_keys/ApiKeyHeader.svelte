<script>
  import { Button } from '$lib/components/shadcn/button/index.js';
  import { Plus } from 'phosphor-svelte';

  let { account, onCreate } = $props();
</script>

<div class="flex items-center justify-between mb-6">
  <div>
    <h1 class="text-2xl font-bold">External Access</h1>
    <p class="text-muted-foreground">
      Keys for external agents and tools to access {account.name} in HelixKit.
    </p>
  </div>
  <Button onclick={onCreate}>
    <Plus class="mr-2" size={16} />
    Create Key
  </Button>
</div>
