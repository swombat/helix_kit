<script>
	import { cn } from "$lib/utils.js";

	let {
    errors = [], // array of errors
	} = $props();

   // Function to capitalize the first letter of the sentence
  function formatError(text) {
    return text.charAt(0).toUpperCase() + text.slice(1);
  }
</script>

{#if errors.length > 0}
  <div class="gap-2 -mt-1">
    {#each errors as error}
      <div
        class="text-xs text-destructive"
      >
        {formatError(error)}
      </div>
    {/each}
  </div>
{/if}