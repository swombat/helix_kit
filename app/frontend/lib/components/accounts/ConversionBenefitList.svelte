<script>
  import { CheckCircle } from 'phosphor-svelte';

  let { title, benefits = [] } = $props();
</script>

<div class="space-y-4">
  <h3 class="font-semibold text-neutral-400 dark:text-neutral-600 text-lg">{title}</h3>

  <div class="space-y-3">
    {#each benefits as benefit}
      <div class="flex gap-3">
        <CheckCircle class="h-5 w-5 text-green-500 mt-0.5 flex-shrink-0" />
        <div>
          <p class="font-medium">{benefit.title}</p>
          <p class="text-sm text-muted-foreground">{benefit.description}</p>
        </div>
      </div>
    {/each}
  </div>
</div>
