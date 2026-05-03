<script>
  import * as Card from '$lib/components/shadcn/card/index.js';
  import { Notepad } from 'phosphor-svelte';
</script>

<Card.Root class="h-[calc(100vh-16rem)]">
  <Card.Content class="h-full flex items-center justify-center">
    <div class="text-center text-muted-foreground">
      <Notepad class="mx-auto size-12 mb-4" weight="duotone" />
      <p>Select a whiteboard to view its contents</p>
    </div>
  </Card.Content>
</Card.Root>
