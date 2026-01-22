<script>
  import { WarningCircle, ShieldCheck } from 'phosphor-svelte';
  import * as Drawer from '$lib/components/shadcn/drawer/index.js';

  let { scores = {} } = $props();
  let open = $state(false);

  const maxScore = $derived(scores ? Math.max(...Object.values(scores).map(Number)) : 0);

  // Flagged at 0.5+, high severity at 0.8+
  const isFlagged = $derived(maxScore >= 0.5);
  const isHigh = $derived(maxScore >= 0.8);

  // For scores below 0.5, scale opacity from 0.15 (at 0) to 0.6 (at 0.5)
  // This makes higher scores more visible
  const opacity = $derived(isFlagged ? 1 : 0.15 + (maxScore / 0.5) * 0.45);

  // Green for clean/pass, amber for detected but not flagged, orange/red for flagged
  const colorClass = $derived(
    isHigh ? 'text-red-500' : isFlagged ? 'text-orange-500' : maxScore >= 0.1 ? 'text-amber-500' : 'text-green-500'
  );

  const sortedScores = $derived(
    Object.entries(scores || {})
      .filter(([, score]) => score > 0.01)
      .sort(([, a], [, b]) => b - a)
  );

  function formatCategory(name) {
    return name.replace(/[/_-]/g, ' ').replace(/\b\w/g, (c) => c.toUpperCase());
  }
</script>

{#if scores && Object.keys(scores).length > 0}
  <button onclick={() => (open = true)} class="p-1 rounded-full hover:bg-muted {colorClass}" style="opacity: {opacity}">
    {#if isFlagged}
      <WarningCircle size={16} weight="fill" />
    {:else}
      <ShieldCheck size={16} weight="regular" />
    {/if}
  </button>

  <Drawer.Root bind:open direction="bottom">
    <Drawer.Content class="max-h-[60vh]">
      <Drawer.Header>
        <Drawer.Title class="flex items-center gap-2">
          {#if isFlagged}
            <WarningCircle size={20} weight="fill" class={colorClass} />
          {:else}
            <ShieldCheck size={20} weight="fill" class={colorClass} />
          {/if}
          Content Moderation
        </Drawer.Title>
      </Drawer.Header>

      <div class="p-4 space-y-3 overflow-y-auto">
        {#each sortedScores as [category, score]}
          <div class="flex items-center gap-3 p-2 rounded {score >= 0.5 ? 'bg-muted' : ''}">
            <div class="flex-1">
              <div class="flex items-center justify-between mb-1">
                <span class="text-sm font-medium">{formatCategory(category)}</span>
                <span class="text-xs text-muted-foreground">{(score * 100).toFixed(0)}%</span>
              </div>
              <div class="h-2 bg-muted rounded-full overflow-hidden">
                <div
                  class="h-full {score >= 0.8
                    ? 'bg-red-500'
                    : score >= 0.5
                      ? 'bg-orange-500'
                      : score >= 0.1
                        ? 'bg-amber-400'
                        : 'bg-green-400'}"
                  style="width: {Math.max(score * 100, 2)}%">
                </div>
              </div>
            </div>
          </div>
        {/each}
        <p class="text-xs text-muted-foreground mt-4 pt-4 border-t">
          Scores indicate likelihood of content matching each category.
        </p>
      </div>
    </Drawer.Content>
  </Drawer.Root>
{/if}
