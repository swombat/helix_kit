<script>
  import { router } from '@inertiajs/svelte';
  import { Button } from '$lib/components/shadcn/button';

  let { interactions = [], pagination = {}, account, agent } = $props();

  const tokenColumns = [
    ['uncached_input_tokens', 'Ordinary'],
    ['cache_creation_input_tokens', 'Write'],
    ['cache_read_input_tokens', 'Read'],
    ['output_tokens', 'Output'],
    ['reasoning_output_tokens', 'Reasoning'],
  ];

  function number(value) {
    return value === null || value === undefined ? '—' : new Intl.NumberFormat('en-US').format(value);
  }

  function dollars(value) {
    if (value === null || value === undefined) return 'Cost unavailable';

    const amount = Number(value);
    const digits = amount < 0.01 ? 4 : 2;
    return `≈${new Intl.NumberFormat('en-US', {
      style: 'currency',
      currency: 'USD',
      minimumFractionDigits: digits,
      maximumFractionDigits: digits,
    }).format(amount)}`;
  }

  function dateTime(value) {
    return value
      ? new Intl.DateTimeFormat('en-GB', { dateStyle: 'medium', timeStyle: 'short' }).format(new Date(value))
      : 'Unknown';
  }

  function duration(value) {
    if (value === null || value === undefined) return 'unknown duration';
    if (value < 1000) return `${value}ms`;
    return `${(value / 1000).toFixed(1)}s`;
  }

  function goToPage(page) {
    router.get(
      `/accounts/${account.id}/agents/${agent.id}/edit`,
      { tab: 'interactions', page },
      {
        preserveScroll: true,
        preserveState: false,
      }
    );
  }

  function telemetryClass(state) {
    if (state === 'complete') return 'bg-green-100 text-green-800 dark:bg-green-950 dark:text-green-300';
    if (state === 'unsupported') return 'bg-red-100 text-red-800 dark:bg-red-950 dark:text-red-300';
    return 'bg-amber-100 text-amber-800 dark:bg-amber-950 dark:text-amber-300';
  }
</script>

<div class="space-y-5">
  <div>
    <h2 class="text-xl font-semibold">Interactions</h2>
    <p class="text-sm text-muted-foreground">
      Runtime interactions in reverse chronological order. Token values are shown only when the runtime reported
      trigger-local instrumentation. Costs are estimates using public API prices as of 22 July 2026.
    </p>
  </div>

  {#if interactions.length === 0}
    <div class="rounded border p-8 text-center text-sm text-muted-foreground">
      No runtime interactions recorded yet.
    </div>
  {:else}
    <div class="space-y-3">
      {#each interactions as interaction}
        <div class="rounded border bg-card p-4">
          <div class="flex flex-col justify-between gap-3 md:flex-row md:items-start">
            <div class="min-w-0">
              <div class="flex flex-wrap items-center gap-2">
                <span class="font-medium">{interaction.summary}</span>
                <span class={`rounded px-2 py-0.5 text-xs ${telemetryClass(interaction.telemetry_state)}`}>
                  {interaction.telemetry_state}
                </span>
              </div>
              <div class="mt-1 text-sm text-muted-foreground">
                {dateTime(interaction.started_at)} · {duration(interaction.duration_ms)}
                {#if interaction.provider || interaction.model}
                  · {interaction.provider || 'unknown provider'} / {interaction.model || 'unknown model'}
                {/if}
              </div>
              <div class="mt-2 text-sm">
                {#if interaction.chat_id}
                  <a
                    class="font-medium text-primary hover:underline"
                    href={`/accounts/${account.id}/chats/${interaction.chat_id}`}>
                    {interaction.chat_title || 'Untitled conversation'}
                  </a>
                {:else}
                  <span class="text-muted-foreground">Not attached to a conversation</span>
                {/if}
                {#if interaction.requested_by}
                  <span class="text-muted-foreground"> · {interaction.requested_by}</span>
                {/if}
              </div>
            </div>
            <div class="text-right text-xs text-muted-foreground">
              <div class="font-medium text-foreground">{dollars(interaction.estimated_cost?.amount_usd)}</div>
              <div>
                {interaction.provider_request_count === null || interaction.provider_request_count === undefined
                  ? 'Provider calls unavailable'
                  : `${interaction.provider_request_count} provider call${interaction.provider_request_count === 1 ? '' : 's'}`}
              </div>
            </div>
          </div>

          <div class="mt-4 grid grid-cols-2 gap-2 sm:grid-cols-5">
            {#each tokenColumns as [key, label]}
              <div class="rounded bg-muted/50 p-2">
                <div class="text-xs text-muted-foreground">{label}</div>
                <div class="font-mono text-sm font-medium">{number(interaction.tokens?.[key])}</div>
              </div>
            {/each}
          </div>
        </div>
      {/each}
    </div>
  {/if}

  {#if pagination.pages > 1}
    <div class="flex items-center justify-between gap-3 border-t pt-4">
      <p class="text-sm text-muted-foreground">
        {pagination.from}–{pagination.to} of {pagination.count}
      </p>
      <div class="flex gap-2">
        <Button
          type="button"
          variant="outline"
          size="sm"
          disabled={!pagination.prev}
          onclick={() => goToPage(pagination.prev)}>
          Previous
        </Button>
        <Button
          type="button"
          variant="outline"
          size="sm"
          disabled={!pagination.next}
          onclick={() => goToPage(pagination.next)}>
          Next
        </Button>
      </div>
    </div>
  {/if}
</div>
