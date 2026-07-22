<script>
  import { Badge } from '$lib/components/shadcn/badge/index.js';
  import ParticipantAvatars from '$lib/components/chat/ParticipantAvatars.svelte';
  import { formatTokenCount } from '$lib/chat-utils';
  import { formatCompactTelemetryTokens } from '$lib/message-telemetry';

  let {
    chat,
    agents = [],
    allMessages = [],
    contextTokens = 0,
    costTokens = { input: 0, output: 0 },
    costBreakdown = {},
    tokenWarningLevel = 'none',
  } = $props();

  const detailedCosts = $derived(costBreakdown?.totals);
  const hasDetailedCosts = $derived((costBreakdown?.row_count || 0) > 0);

  function dollars(value) {
    const amount = Number(value);
    const digits = amount < 0.01 ? 4 : 2;
    return `≈${new Intl.NumberFormat('en-US', {
      style: 'currency',
      currency: 'USD',
      minimumFractionDigits: digits,
      maximumFractionDigits: digits,
    }).format(amount)}`;
  }
</script>

<div class="text-sm text-muted-foreground flex items-center gap-2 flex-wrap">
  {#if chat?.manual_responses}
    <ParticipantAvatars {agents} messages={allMessages} />
  {:else}
    {chat?.model_label || chat?.model_id || 'Auto'}
  {/if}

  <span class="ml-2 text-xs">
    Context: {formatTokenCount(contextTokens)} · Cost:
    {#if hasDetailedCosts}
      {formatCompactTelemetryTokens(detailedCosts?.uncached_input_tokens)} input · {formatCompactTelemetryTokens(
        detailedCosts?.cache_read_input_tokens
      )} cache read · {formatCompactTelemetryTokens(detailedCosts?.cache_creation_input_tokens)} cache write · {formatCompactTelemetryTokens(
        detailedCosts?.output_tokens
      )} output
    {:else}
      {formatTokenCount(costTokens.input)} input · {formatTokenCount(costTokens.output)} output
    {/if}
    {#if costBreakdown?.estimated_cost?.amount_usd}
      ·
      <span
        title={`Estimated from ${costBreakdown.estimated_cost.interaction_count} priced interactions using ${costBreakdown.estimated_cost.pricing_as_of} prices`}>
        Estimated: {dollars(costBreakdown.estimated_cost.amount_usd)}
      </span>
    {/if}
  </span>

  {#if tokenWarningLevel === 'amber'}
    <Badge
      variant="outline"
      class="bg-amber-100 text-amber-800 border-amber-300 dark:bg-amber-900/30 dark:text-amber-400 dark:border-amber-700">
      Long conversation
    </Badge>
  {:else if tokenWarningLevel === 'red'}
    <Badge
      variant="outline"
      class="bg-red-100 text-red-800 border-red-300 dark:bg-red-900/30 dark:text-red-400 dark:border-red-700">
      Very long
    </Badge>
  {:else if tokenWarningLevel === 'critical'}
    <Badge variant="destructive">Extremely long</Badge>
  {/if}
</div>
