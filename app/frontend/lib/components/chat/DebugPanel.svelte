<script>
  let { logs = [], onclear } = $props();
</script>

<div class="border-b border-orange-300 bg-orange-50 dark:bg-orange-950/30 px-4 md:px-6 py-2 max-h-48 overflow-y-auto">
  <div class="flex justify-between items-center mb-2">
    <span class="text-xs font-semibold text-orange-700 dark:text-orange-400">Debug Log</span>
    <button onclick={onclear} class="text-xs text-orange-600 hover:text-orange-800 dark:text-orange-400">
      Clear
    </button>
  </div>
  {#if logs.length === 0}
    <p class="text-xs text-orange-600/70 dark:text-orange-400/70">
      No debug logs yet. Trigger an agent response to see logs.
    </p>
  {:else}
    <div class="space-y-1 font-mono text-xs">
      {#each logs as log}
        <div
          class="flex gap-2 {log.level === 'error'
            ? 'text-red-600'
            : log.level === 'warn'
              ? 'text-amber-600'
              : 'text-orange-700 dark:text-orange-300'}">
          <span class="text-orange-400 dark:text-orange-500 shrink-0">[{log.time}]</span>
          <span class="break-all">{log.message}</span>
        </div>
      {/each}
    </div>
  {/if}
</div>
