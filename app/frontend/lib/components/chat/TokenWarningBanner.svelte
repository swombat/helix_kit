<script>
  import { WarningCircle } from 'phosphor-svelte';
  import { formatTokenCount } from '$lib/chat-utils';

  let { level = null, contextTokens = 0 } = $props();
</script>

{#if level === 'critical'}
  <div
    class="bg-red-100 dark:bg-red-900/50 border-b border-red-200 dark:border-red-800 px-4 py-2 text-sm text-red-800 dark:text-red-200">
    <WarningCircle size={16} class="inline mr-2" weight="fill" />
    This conversation is very long ({formatTokenCount(contextTokens)} tokens of context). Consider starting a new conversation.
  </div>
{/if}
