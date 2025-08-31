<script>
  import { Card, CardContent, CardHeader, CardTitle } from '$lib/components/shadcn/card';
  import * as PhosphorIcons from 'phosphor-svelte';

  let { title, icon = null, iconSize = 20, iconWeight = 'regular', class: className = '' } = $props();

  // Get the icon component dynamically
  const IconComponent = $derived(icon ? PhosphorIcons[icon] : null);
</script>

<Card class={className}>
  <CardHeader>
    <CardTitle class="mb-2 flex items-center gap-2">
      {#if IconComponent}
        <IconComponent size={iconSize} weight={iconWeight} class="text-muted-foreground" />
      {/if}
      {title}
    </CardTitle>
  </CardHeader>
  <CardContent>
    <slot />
  </CardContent>
</Card>
