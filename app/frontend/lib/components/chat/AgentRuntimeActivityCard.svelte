<script>
  import * as Card from '$lib/components/shadcn/card/index.js';
  import { Spinner, TerminalWindow, WarningCircle, CheckCircle } from 'phosphor-svelte';
  import { formatTime, formatDateTime } from '$lib/utils';
  import { agentIconFor } from '$lib/agent-icons';

  let { interaction } = $props();

  const AgentIcon = $derived(agentIconFor(interaction.agent_icon));
  const isRunning = $derived(interaction.status === 'running');
  const isFailed = $derived(interaction.status === 'failed');
  const hasOutput = $derived(Boolean(interaction.stdout || interaction.stderr));

  function durationLabel(durationMs) {
    if (durationMs === null || durationMs === undefined) return null;
    if (durationMs < 1000) return `${durationMs}ms`;
    return `${(durationMs / 1000).toFixed(1)}s`;
  }
</script>

<div class="flex justify-start group">
  <div class="max-w-[85%] md:max-w-[70%]">
    <Card.Root
      class="border-dashed bg-muted/20 {isFailed
        ? 'border-destructive/50 bg-destructive/5'
        : 'border-muted-foreground/30'}">
      <Card.Content class="p-4 space-y-3">
        <div class="flex items-start gap-3">
          <div
            class="mt-0.5 rounded-full border bg-background p-1.5 {isFailed
              ? 'text-destructive'
              : 'text-muted-foreground'}">
            {#if isRunning}
              <Spinner size={16} class="animate-spin" />
            {:else if isFailed}
              <WarningCircle size={16} weight="duotone" />
            {:else}
              <CheckCircle size={16} weight="duotone" />
            {/if}
          </div>

          <div class="min-w-0 flex-1 space-y-1">
            <div class="flex flex-wrap items-center gap-1.5 text-sm">
              <AgentIcon
                size={15}
                weight="duotone"
                class={interaction.agent_colour
                  ? `text-${interaction.agent_colour}-600 dark:text-${interaction.agent_colour}-400`
                  : 'text-muted-foreground'} />
              <span class="font-medium">{interaction.agent_name}</span>
              <span class="text-muted-foreground">{interaction.status_label}</span>
            </div>

            <div class="text-xs text-muted-foreground">
              Hosted runtime activity, not a chat reply
              {#if durationLabel(interaction.duration_ms)}
                · {durationLabel(interaction.duration_ms)}
              {/if}
              {#if interaction.runtime_status}
                · runtime {interaction.runtime_status}
              {/if}
              {#if interaction.transport_status}
                · transport {interaction.transport_status}
              {/if}
            </div>
          </div>
        </div>

        {#if interaction.error_message}
          <div class="rounded border border-destructive/30 bg-destructive/10 p-2 text-xs text-destructive">
            {#if interaction.error_class}<span class="font-mono"
                >{interaction.error_class}:
              </span>{/if}{interaction.error_message}
          </div>
        {/if}

        {#if hasOutput}
          <details class="rounded border bg-background/70 p-2 text-xs">
            <summary class="flex cursor-pointer items-center gap-1.5 font-medium text-muted-foreground">
              <TerminalWindow size={14} weight="duotone" />
              Runtime output
            </summary>
            {#if interaction.stdout}
              <div class="mt-2">
                <div class="mb-1 font-medium text-muted-foreground">stdout</div>
                <pre
                  class="max-h-80 overflow-auto whitespace-pre-wrap rounded bg-muted p-3 font-mono text-xs">{interaction.stdout}</pre>
              </div>
            {/if}
            {#if interaction.stderr}
              <div class="mt-2">
                <div class="mb-1 font-medium text-destructive">stderr</div>
                <pre
                  class="max-h-80 overflow-auto whitespace-pre-wrap rounded bg-destructive/10 p-3 font-mono text-xs text-destructive">{interaction.stderr}</pre>
              </div>
            {/if}
          </details>
        {/if}
      </Card.Content>
    </Card.Root>

    <div class="mt-1 text-xs text-muted-foreground flex items-center gap-2">
      <span class="group">
        {formatTime(interaction.created_at)}
        <span class="hidden group-hover:inline-block">({formatDateTime(interaction.created_at, true)})</span>
      </span>
    </div>
  </div>
</div>
