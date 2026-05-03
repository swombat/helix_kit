<script>
  import { buttonVariants } from '$lib/components/shadcn/button/button.svelte';
  import * as Card from '$lib/components/shadcn/card/index.js';
  import { ArrowUpRight } from 'phosphor-svelte';

  let { feature, muted = false } = $props();
  let Icon = $derived(feature.icon);
</script>

<Card.Root class="flex flex-col justify-between {muted ? 'opacity-75 h-full' : ''}">
  <Card.Header class={muted ? 'flex-1' : ''}>
    <div class="flex items-start gap-4">
      <div class="flex-shrink-0">
        <Icon size={48} weight="duotone" class={muted ? 'text-muted-foreground' : 'text-primary'} />
      </div>
      <div class="flex-1">
        <Card.Title class="mb-2">{feature.title}</Card.Title>
        <Card.Description>{feature.description}</Card.Description>
      </div>
    </div>
  </Card.Header>
  {#if feature.link || muted}
    <Card.Content class="flex justify-end">
      {#if feature.link}
        <a href={feature.link} class={buttonVariants({ variant: 'ghost' })} target="_blank" rel="noopener noreferrer">
          <span>See more </span>
          <ArrowUpRight weight="bold" />
        </a>
      {:else}
        <div class="h-10"></div>
      {/if}
    </Card.Content>
  {/if}
</Card.Root>
