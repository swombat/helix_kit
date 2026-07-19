<script>
  import * as Drawer from '$lib/components/shadcn/drawer/index.js';
  import { Button } from '$lib/components/shadcn/button';
  import { X } from 'phosphor-svelte';

  let { open = $bindable(false), breakdown = {} } = $props();

  const tokenColumns = [
    ['uncached_input_tokens', 'Ordinary input'],
    ['cache_creation_input_tokens', 'Cache writes'],
    ['cache_read_input_tokens', 'Cache reads'],
    ['output_tokens', 'Output'],
    ['reasoning_output_tokens', 'Reasoning'],
  ];

  function tokens(value) {
    return value === null || value === undefined ? 'Unavailable' : new Intl.NumberFormat('en-US').format(value);
  }
</script>

<Drawer.Root bind:open direction="bottom">
  <Drawer.Content class="max-h-[80vh]">
    <Drawer.Header class="sr-only">
      <Drawer.Title>Conversation costs</Drawer.Title>
      <Drawer.Description>Token usage grouped by model for this conversation.</Drawer.Description>
    </Drawer.Header>

    <div class="flex max-h-[75vh] flex-col">
      <div class="flex items-start justify-between gap-4 border-b px-4 py-3 md:px-6">
        <div>
          <h3 class="text-lg font-semibold">Conversation costs</h3>
          <p class="text-sm text-muted-foreground">
            Token usage recorded for each model in this conversation. Unknown categories are not treated as zero.
          </p>
        </div>
        <Button variant="ghost" size="icon" onclick={() => (open = false)} aria-label="Close costs">
          <X size={18} />
        </Button>
      </div>

      <div class="overflow-y-auto px-4 py-4 md:px-6">
        <div
          class={`mb-4 rounded border p-3 text-sm ${
            breakdown.instrumentation_complete
              ? 'border-green-300 bg-green-50 text-green-900 dark:border-green-900 dark:bg-green-950 dark:text-green-200'
              : 'border-amber-300 bg-amber-50 text-amber-900 dark:border-amber-900 dark:bg-amber-950 dark:text-amber-200'
          }`}>
          {breakdown.instrumentation_note || 'Instrumentation status is unavailable.'}
          {#if breakdown.row_count}
            <span class="block text-xs opacity-80">
              {breakdown.complete_rows || 0} complete · {breakdown.incomplete_rows || 0} incomplete recorded rows
            </span>
          {/if}
        </div>

        {#if !breakdown.models?.length}
          <p class="py-8 text-center text-sm text-muted-foreground">No model usage has been recorded yet.</p>
        {:else}
          <div class="overflow-x-auto rounded border">
            <table class="w-full min-w-[900px] text-left text-sm">
              <thead class="border-b bg-muted/50 text-xs text-muted-foreground">
                <tr>
                  <th class="px-3 py-2">Model</th>
                  {#each tokenColumns as [, label]}
                    <th class="px-3 py-2 text-right">{label}</th>
                  {/each}
                  <th class="px-3 py-2 text-right">Coverage</th>
                </tr>
              </thead>
              <tbody>
                {#each breakdown.models as model}
                  <tr class="border-b last:border-0">
                    <td class="px-3 py-3">
                      <div class="font-medium">{model.model}</div>
                      <div class="text-xs text-muted-foreground">
                        {model.provider || 'Unknown provider'} · {model.sources?.join(' + ') || 'unknown source'}
                      </div>
                    </td>
                    {#each tokenColumns as [key]}
                      <td class="px-3 py-3 text-right font-mono text-xs">{tokens(model.tokens?.[key])}</td>
                    {/each}
                    <td class="px-3 py-3 text-right text-xs">
                      <div>{model.complete_rows || 0} complete</div>
                      {#if model.incomplete_rows}
                        <div class="text-amber-700 dark:text-amber-400">{model.incomplete_rows} incomplete</div>
                      {/if}
                    </td>
                  </tr>
                {/each}
              </tbody>
              <tfoot class="border-t bg-muted/30 font-medium">
                <tr>
                  <td class="px-3 py-3">Known totals</td>
                  {#each tokenColumns as [key]}
                    <td class="px-3 py-3 text-right font-mono text-xs">{tokens(breakdown.totals?.[key])}</td>
                  {/each}
                  <td class="px-3 py-3 text-right text-xs">{breakdown.row_count || 0} rows</td>
                </tr>
              </tfoot>
            </table>
          </div>
        {/if}
      </div>
    </div>
  </Drawer.Content>
</Drawer.Root>
