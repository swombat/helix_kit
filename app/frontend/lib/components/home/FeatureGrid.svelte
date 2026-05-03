<script>
  import FeatureCard from '$lib/components/home/FeatureCard.svelte';

  let { title, features = [], muted = false } = $props();
</script>

<div>
  <h2 class="text-2xl font-semibold mb-4">{title}</h2>
  <div class="grid gap-4 md:grid-cols-2 lg:grid-cols-3">
    {#each features as feature}
      <FeatureCard {feature} {muted} />
    {/each}
  </div>
</div>
