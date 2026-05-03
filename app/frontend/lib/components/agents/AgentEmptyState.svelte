<script>
  import { Button } from '$lib/components/shadcn/button/index.js';
  import { Card, CardContent } from '$lib/components/shadcn/card';
  import { Plus, Robot } from 'phosphor-svelte';

  let { onCreate } = $props();
</script>

<Card>
  <CardContent class="py-16 text-center">
    <Robot class="mx-auto size-16 text-muted-foreground mb-4" weight="duotone" />
    <h2 class="text-xl font-semibold mb-2">No agents yet</h2>
    <p class="text-muted-foreground mb-6">
      Create your first agent to define a custom AI personality with specific tools and capabilities.
    </p>
    <Button onclick={onCreate}>
      <Plus class="mr-2 size-4" />
      Create Your First Agent
    </Button>
  </CardContent>
</Card>
