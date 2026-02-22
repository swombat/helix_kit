<script>
  import { fade } from 'svelte/transition';

  let { message = null, variant = 'error' } = $props();
</script>

{#if message}
  <div
    class="fixed bottom-4 right-4 px-4 py-2 rounded-lg shadow-lg z-50 {variant === 'success'
      ? 'bg-green-600 text-white'
      : 'bg-destructive text-destructive-foreground'}"
    transition:fade>
    {message}
  </div>
{/if}
