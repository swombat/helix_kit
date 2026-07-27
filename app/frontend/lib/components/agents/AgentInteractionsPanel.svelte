<script>
  import { router } from '@inertiajs/svelte';
  import { Button } from '$lib/components/shadcn/button';

  let { interactions = [], pagination = {}, account, agent, runtimeObservabilityUrl = null } = $props();

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

  function bytes(value) {
    if (value === null || value === undefined) return 'unknown';
    if (value < 1024) return `${value} B`;
    if (value < 1024 * 1024) return `${(value / 1024).toFixed(1)} KiB`;
    return `${(value / 1024 / 1024).toFixed(1)} MiB`;
  }
</script>

<div class="space-y-5">
  <div class="flex flex-col gap-3 sm:flex-row sm:items-start sm:justify-between">
    <div>
      <h2 class="text-xl font-semibold">Sessions</h2>
      <p class="text-sm text-muted-foreground">
        Agent runtime sessions in reverse chronological order. Token values are shown only when the runtime reported
        trigger-local instrumentation. Costs are estimates using public API prices as of 22 July 2026.
      </p>
      <p class="mt-1 text-xs text-muted-foreground">
        Diagnostic stdout and stderr are stored per trigger. The runtime currently retains only the final 4,000
        characters of each stream; a 4,000-character value may therefore be truncated.
      </p>
    </div>
    {#if runtimeObservabilityUrl}
      <a href={runtimeObservabilityUrl}>
        <Button type="button" variant="outline" size="sm">Detailed runtime usage</Button>
      </a>
    {/if}
  </div>

  {#if interactions.length === 0}
    <div class="rounded border p-8 text-center text-sm text-muted-foreground">No runtime sessions recorded yet.</div>
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
              <div
                class:line-through={interaction.subscription_based}
                class="font-medium text-foreground"
                title={interaction.subscription_based
                  ? 'This agent activation used a provider subscription, so this API-equivalent estimate does not apply.'
                  : undefined}>
                {dollars(interaction.estimated_cost?.amount_usd)}
              </div>
              {#if interaction.subscription_based}
                <div title="Provider subscription usage is covered by the connected personal plan.">Subscription</div>
              {/if}
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

          <details class="mt-4 rounded border bg-muted/30 text-sm">
            <summary class="cursor-pointer px-3 py-2 font-medium">Session diagnostics and output</summary>
            <div class="space-y-3 border-t p-3">
              <div class="grid gap-2 text-xs sm:grid-cols-2 lg:grid-cols-3">
                <div>
                  <span class="text-muted-foreground">Logical session:</span>
                  <span class="font-mono">{interaction.session_id || 'unknown'}</span>
                </div>
                <div>
                  <span class="text-muted-foreground">Chaos process:</span>
                  <span class="font-mono">{interaction.chaos_session_id || 'unknown'}</span>
                </div>
                <div>
                  <span class="text-muted-foreground">Transport/runtime:</span>
                  {interaction.transport_status ?? 'n/a'} / {interaction.runtime_status || 'n/a'} /
                  {interaction.runtime_returncode ?? 'n/a'}
                </div>
                <div>
                  <span class="text-muted-foreground">Lifecycle:</span>
                  {interaction.session_outcome || 'unknown'}
                  {#if interaction.session_roll_reason}
                    · {interaction.session_roll_reason}{/if}
                </div>
                <div>
                  <span class="text-muted-foreground">Prompt:</span>
                  {interaction.prompt_mode || 'unknown'} · selected {bytes(interaction.selected_prompt_bytes)}
                </div>
                <div>
                  <span class="text-muted-foreground">Chaos/cache:</span>
                  {interaction.chaos_version || 'unknown'} / {interaction.cache_ttl || 'unknown'}
                </div>
              </div>

              {#if Object.keys(interaction.prompt_component_bytes || {}).length}
                <div class="text-xs text-muted-foreground">
                  Prompt components:
                  {Object.entries(interaction.prompt_component_bytes)
                    .map(([key, value]) => `${key} ${bytes(value)}`)
                    .join(' · ')}
                </div>
              {/if}

              {#if interaction.error_message}
                <div class="rounded border border-destructive/30 bg-destructive/10 p-2 text-xs text-destructive">
                  {interaction.error_class}: {interaction.error_message}
                </div>
              {/if}

              {#if interaction.stdout}
                <details>
                  <summary class="cursor-pointer font-medium">
                    stdout ({number(interaction.stdout_chars)} characters)
                    {#if interaction.stdout_may_be_truncated}
                      <span class="text-amber-700 dark:text-amber-400">· tail only</span>
                    {/if}
                  </summary>
                  <pre
                    class="mt-1 max-h-96 overflow-auto whitespace-pre-wrap rounded bg-background p-3 text-xs">{interaction.stdout}</pre>
                </details>
              {:else}
                <p class="text-xs text-muted-foreground">No stdout was captured.</p>
              {/if}

              {#if interaction.stderr}
                <details>
                  <summary class="cursor-pointer font-medium text-destructive">
                    stderr ({number(interaction.stderr_chars)} characters)
                    {#if interaction.stderr_may_be_truncated}
                      <span class="text-amber-700 dark:text-amber-400">· tail only</span>
                    {/if}
                  </summary>
                  <pre
                    class="mt-1 max-h-96 overflow-auto whitespace-pre-wrap rounded bg-background p-3 text-xs">{interaction.stderr}</pre>
                </details>
              {/if}
            </div>
          </details>
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
