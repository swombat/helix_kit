<script>
  import { cn } from '$lib/utils.js';

  let { value = $bindable(null), options = [], label = 'Colour' } = $props();

  // Map colour names to their Tailwind classes for display
  const colourClasses = {
    slate: 'bg-slate-100 dark:bg-slate-900',
    gray: 'bg-gray-100 dark:bg-gray-900',
    zinc: 'bg-zinc-100 dark:bg-zinc-900',
    neutral: 'bg-neutral-100 dark:bg-neutral-900',
    stone: 'bg-stone-100 dark:bg-stone-900',
    red: 'bg-red-100 dark:bg-red-900',
    orange: 'bg-orange-100 dark:bg-orange-900',
    amber: 'bg-amber-100 dark:bg-amber-900',
    yellow: 'bg-yellow-100 dark:bg-yellow-900',
    lime: 'bg-lime-100 dark:bg-lime-900',
    green: 'bg-green-100 dark:bg-green-900',
    emerald: 'bg-emerald-100 dark:bg-emerald-900',
    teal: 'bg-teal-100 dark:bg-teal-900',
    cyan: 'bg-cyan-100 dark:bg-cyan-900',
    sky: 'bg-sky-100 dark:bg-sky-900',
    blue: 'bg-blue-100 dark:bg-blue-900',
    indigo: 'bg-indigo-100 dark:bg-indigo-900',
    violet: 'bg-violet-100 dark:bg-violet-900',
    purple: 'bg-purple-100 dark:bg-purple-900',
    fuchsia: 'bg-fuchsia-100 dark:bg-fuchsia-900',
    pink: 'bg-pink-100 dark:bg-pink-900',
    rose: 'bg-rose-100 dark:bg-rose-900',
  };

  function selectColour(colour) {
    value = colour;
  }

  function capitalise(str) {
    return str.charAt(0).toUpperCase() + str.slice(1);
  }
</script>

<div class="space-y-2">
  <label class="text-sm font-medium leading-none">{label}</label>
  <div class="flex flex-wrap gap-2">
    <!-- None/Default option -->
    <button
      type="button"
      onclick={() => selectColour(null)}
      class={cn(
        'w-8 h-8 rounded-md border-2 transition-all flex items-center justify-center',
        'bg-card hover:scale-110',
        value === null ? 'border-primary ring-2 ring-primary/20' : 'border-border'
      )}
      title="None (default)">
      <span class="text-xs text-muted-foreground">-</span>
    </button>

    <!-- Colour swatches -->
    {#each options as colour}
      <button
        type="button"
        onclick={() => selectColour(colour)}
        class={cn(
          'w-8 h-8 rounded-md border-2 transition-all hover:scale-110',
          colourClasses[colour],
          value === colour ? 'border-primary ring-2 ring-primary/20' : 'border-border'
        )}
        title={capitalise(colour)}>
      </button>
    {/each}
  </div>
  {#if value}
    <p class="text-xs text-muted-foreground">Selected: {capitalise(value)}</p>
  {:else}
    <p class="text-xs text-muted-foreground">No colour selected (uses default)</p>
  {/if}
</div>
