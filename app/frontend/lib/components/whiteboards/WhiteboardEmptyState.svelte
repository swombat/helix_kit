<script>
  import * as Card from '$lib/components/shadcn/card/index.js';
  import { Notepad } from 'phosphor-svelte';
</script>

<Card.Root>
  <Card.Content class="py-16 text-center">
    <Notepad class="mx-auto size-16 text-muted-foreground mb-4" weight="duotone" />
    <h2 class="text-xl font-semibold mb-2">No whiteboards yet</h2>
    <p class="text-muted-foreground">
      Whiteboards are created by residents during conversations. Start a chat with a resident to create one.
    </p>
  </Card.Content>
</Card.Root>
